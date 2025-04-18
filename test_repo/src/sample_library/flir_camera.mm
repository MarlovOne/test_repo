// FLIR Camera implementation for iOS using Objective-C++
#import <Foundation/Foundation.h>
// Import FLIR SDK headers for iOS
#import <ThermalSDK/ThermalSDK.h>
#import <objc/runtime.h> // For objc_setAssociatedObject and objc_getAssociatedObject

// C++ standard library and OpenCV
#include <mutex>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <optional>
#include <test_repo/flir_camera.hpp>

// Forward declaration
namespace netxten::camera {
class FlirCameraImpl;
}

// First, let's define our Objective-C interfaces at global scope
@interface DiscoveryDelegate : NSObject <FLIRDiscoveryEventDelegate>
@property (nonatomic, copy) void (^completionHandler)(FLIRIdentity *identity);
@property (nonatomic, copy) void (^errorHandler)(NSString *errorMessage);
@end

@implementation DiscoveryDelegate

- (instancetype)initWithCompletionHandler:(void (^)(FLIRIdentity *))completion 
                             errorHandler:(void (^)(NSString *))error {
    self = [super init];
    if (self) {
        _completionHandler = completion;
        _errorHandler = error;
    }
    return self;
}

- (void)cameraDiscovered:(FLIRDiscoveredCamera *)discoveredCamera {
    if (_completionHandler) {
        _completionHandler(discoveredCamera.identity);
    }
}

- (void)discoveryError:(NSString *)error 
        netServiceError:(int32_t)nsnetserviceserror 
                     on:(FLIRCommunicationInterface)iface {
    if (_errorHandler) {
        NSString *errorMsg = [NSString stringWithFormat:@"%@ (code: %d, interface: %lu)",
                             error, nsnetserviceserror, (unsigned long)iface];
        _errorHandler(errorMsg);
    }
}

@end

@interface StreamDelegate : NSObject <FLIRStreamDelegate>
@property (nonatomic, copy) void (^frameReceivedCallback)(FLIRThermalImage *thermalImage);
@property (nonatomic, copy) void (^errorCallback)(NSError *error);
@end

@implementation StreamDelegate
- (void)onImageReceived {
    if (_frameReceivedCallback) {
        // Get the thermal image from the thermal streamer
        FLIRThermalStreamer *thermalStreamer = (FLIRThermalStreamer *)objc_getAssociatedObject(self, "thermalStreamer");
        if (!thermalStreamer) return;
        
        NSError *error = nil;
        if (![thermalStreamer update:&error]) {
            NSLog(@"Update error: %@", error.localizedDescription);
            if (_errorCallback) {
                _errorCallback(error);
            }
            return;
        }
        
        // Process the thermal image using the callback
        [thermalStreamer withThermalImage:^(FLIRThermalImage *thermalImage) {
            if (self.frameReceivedCallback) {
                self.frameReceivedCallback(thermalImage);
            }
        }];
    }
}

- (void)onError:(NSError *)error {
    NSLog(@"Stream error: %@", error.localizedDescription);
    if (_errorCallback) {
        _errorCallback(error);
    }
}
@end

namespace netxten::camera {

// Static variable for error status codes
static int g_lastStatusCode = 0;

/**
 * @brief Private implementation class for FlirCamera. Manages low-level
 * interactions with FLIR iOS SDK.
 */
class FlirCamera::FlirCameraImpl {
private:
  FLIRCamera *m_camera = nullptr;           // FLIR camera object
  id m_stream_delegate = nullptr;           // Stream delegate for handling frames
  dispatch_queue_t m_dispatch_queue = nullptr; // Dispatch queue for async operations
  bool m_is_connected = false;              // Connection status
  bool m_is_streaming = false;              // Streaming status
  cv::Mat m_latest_frame;                   // The most recently captured frame
  uint64_t m_frame_counter = 0;             // Counter for received frames
  std::mutex m_frame_mutex;                 // Mutex for thread-safe frame access
  FLIRStream *m_stream = nullptr;           // FLIR stream object
  FLIRThermalStreamer *m_thermal_streamer = nullptr; // FLIR thermal streamer
  friend class StreamDelegate;

  // Helper method to discover a single camera
  FLIRIdentity* discover(FLIRCommunicationInterface interface, NSTimeInterval timeout = 10.0);

public:
  FlirCameraImpl();
  ~FlirCameraImpl();

  // Delete copy/move constructor and assignment operator
  FlirCameraImpl(const FlirCameraImpl &) = delete;
  FlirCameraImpl &operator=(const FlirCameraImpl &) = delete;
  FlirCameraImpl(FlirCameraImpl &&) = delete;
  FlirCameraImpl &operator=(FlirCameraImpl &&) = delete;

  bool connect(const FlirCamera::ConnectionParameters &params);
  void disconnect();
  void autofocus();
  void *captureSnapshot();
  static void freeSnapshot(void *snapshot);
  void startStream();
  void stopStream();
  void playStream();
  void playStreamCV();
  std::pair<uint64_t, std::optional<cv::Mat>>
  getLatestFrame(uint64_t lastSeenFrame);
  std::optional<std::string> getModelName() const;
  std::optional<double> getFrameRate() const;
  std::optional<netxten::types::FrameSize> getFrameSize() const;
  bool isConnected() const;
  bool isStreaming() const;
  
  // Public method to discover multiple cameras
  std::vector<FLIRIdentity*> discoverCameras(int communicationInterface, NSTimeInterval timeout = 10.0);
};

// Implementation of FlirCameraImpl constructor
FlirCamera::FlirCameraImpl::FlirCameraImpl()
    : m_camera(nil),
      m_stream_delegate(nil),
      m_is_connected(false),
      m_is_streaming(false),
      m_frame_counter(0) {
  // Create a serial dispatch queue for camera operations
  m_dispatch_queue = dispatch_queue_create("com.flir.camera.queue", DISPATCH_QUEUE_SERIAL);
}

// Implementation of FlirCameraImpl destructor
FlirCamera::FlirCameraImpl::~FlirCameraImpl() {
  disconnect();
  m_dispatch_queue = nullptr;
}

// Implementation of the discover method
FLIRIdentity* FlirCamera::FlirCameraImpl::discover(FLIRCommunicationInterface interface, NSTimeInterval timeout) {
  @autoreleasepool {
    // Perform camera discovery
    FLIRDiscovery *discovery = [[FLIRDiscovery alloc] init];
    
    __block bool discoveryCompleted = false;
    __block FLIRIdentity *discoveredIdentity = nil;
    
    // Setup discovery delegate
    DiscoveryDelegate *delegate = [[DiscoveryDelegate alloc] 
        initWithCompletionHandler:^(FLIRIdentity *foundIdentity) {
            discoveredIdentity = foundIdentity;
            discoveryCompleted = true;
        } 
        errorHandler:^(NSString *errorMsg) {
            NSLog(@"Discovery error: %@", errorMsg);
            discoveryCompleted = true;
        }];
    
    discovery.delegate = delegate;
    [discovery start:interface];
    
    // Wait for discovery to complete (with timeout)
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!discoveryCompleted && [timeoutDate timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    [discovery stop];
    
    if (!discoveredIdentity) {
        NSLog(@"No camera discovered within timeout period");
    }
    
    return discoveredIdentity;
  }
}

// Now implement the connect method
bool FlirCamera::FlirCameraImpl::connect(
    const FlirCamera::ConnectionParameters &params) {
    
    if (m_is_connected) {
        disconnect();
    }
    
    @autoreleasepool {
        NSError *error = nil;
        
        // Skip explicit SDK initialization as it appears to be unnecessary
        // in the current version of the SDK
        
        FLIRIdentity *identity = nil;
        
        if (params.ip.empty()) {
            // Convert the C++ interface value to Objective-C enum
            FLIRCommunicationInterface interface = FLIRCommunicationInterfaceNetwork;
            if (params.communication_interface == FlirCamera::CommunicationInterface::emulator) {
                interface = FLIRCommunicationInterfaceEmulator;
            } else if (params.communication_interface == FlirCamera::CommunicationInterface::usb) {
                interface = FLIRCommunicationInterfaceLightning; // Use Lightning for iOS as USB equivalent
            }
            
            // Use the discover method to find a camera
            identity = discover(interface);
            
            if (!identity) {
                return false; // Already logged the error in discover method
            }
        } else {
            // Connect to camera with known IP address
            NSString *ipAddress = [NSString stringWithUTF8String:params.ip.c_str()];
            identity = [[FLIRIdentity alloc] initWithIpAddr:ipAddress];
        }

        // Continue with the rest of the connection code
        if (!identity) {
            NSLog(@"Failed to create camera identity");
            return false;
        }
        
        // Create camera instance
        m_camera = [[FLIRCamera alloc] init];
        
        // Authenticate with camera if needed
        if ([identity cameraType] != FLIRCameraType_flirOne && 
            [identity cameraType] != FLIRCameraType_flirOneEdge) {
            
            FLIRAuthenticationStatus status = pending;
            
            // Authentication might require user interaction on the camera
            int authAttempts = 0;
            while (status == pending && authAttempts < 5) {
                NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
                if (!appName) {
                    appName = @"FlirApp";
                }
                NSString *deviceName = [[UIDevice currentDevice] name];
                NSString *connectionName = [NSString stringWithFormat:@"%@ %@", deviceName, appName];
                
                status = [m_camera authenticate:identity trustedConnectionName:connectionName];
                
                if (status == pending) {
                    NSLog(@"Authentication pending. Please approve connection on camera.");
                    // Wait a bit before trying again
                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
                    authAttempts++;
                }
            }
            
            if (status != approved) {
                NSLog(@"Authentication failed with status: %d", (int)status);
                m_camera = nil;
                return false;
            }
        }
        
        // Connect to the camera
        if (![m_camera connect:identity error:&error]) {
            NSLog(@"Failed to connect to camera: %@", error.localizedDescription);
            g_lastStatusCode = static_cast<int>(error.code);
            m_camera = nil;
            return false;
        }
        
        // Successfully connected
        m_is_connected = true;
        return true;
    }
}

void FlirCamera::FlirCameraImpl::disconnect() {
  @autoreleasepool {
    if (!m_is_connected || m_camera == nil) {
      return;
    }

    // Stop streaming if active
    if (m_is_streaming) {
      stopStream();
    }

    // Disconnect from the camera
    NSError *error = nil;
    [m_camera disconnect];

    if (error) {
      NSLog(@"Error while disconnecting: %@", error.localizedDescription);
      g_lastStatusCode = static_cast<int>(error.code);
    }

    // Release the camera object
    m_camera = nil;
    m_is_connected = false;
  }
}

void FlirCamera::FlirCameraImpl::autofocus() {
 @autoreleasepool {
        if (!m_is_connected || m_camera == nil) {
            NSLog(@"Cannot perform autofocus - camera not connected");
            return;
        }
        
        // Get the camera's remote control interface
        FLIRRemoteControl *remoteControl = [m_camera getRemoteControl];
        if (!remoteControl) {
            NSLog(@"Remote control interface not available for this camera");
            return;
        }
        
        // Get the focus controller
        FLIRFocus *flirFocus = [remoteControl getFocus];
        if (!flirFocus) {
            NSLog(@"Focus controller not available for this camera");
            return;
        }
        
        NSError *error = nil;
        
        // Trigger autofocus
        if (![flirFocus autofocus:&error]) {
            NSLog(@"Failed to perform autofocus: %@", error.localizedDescription);
            g_lastStatusCode = static_cast<int>(error.code);
            return;
        }
        
        NSLog(@"Autofocus operation triggered successfully");
    } 
}

void *FlirCamera::FlirCameraImpl::captureSnapshot() {
  // To be implemented
  return nullptr;
}

void FlirCamera::FlirCameraImpl::freeSnapshot(void *snapshot) {
  // To be implemented
}

void FlirCamera::FlirCameraImpl::startStream() {
    @autoreleasepool {
        if (!m_is_connected || m_camera == nil) {
            NSLog(@"Cannot start streaming - camera not connected");
            return;
        }
        
        if (m_is_streaming) {
            NSLog(@"Streaming already active");
            return;
        }
        
        // Get available streams from the camera
        NSArray<FLIRStream *> *streams = [m_camera getStreams];
        if (streams.count == 0) {
            NSLog(@"No streams found on camera!");
            return;
        }
        
        // Use the first stream
        m_stream = streams[0];
        
        // Create and store the stream delegate
        StreamDelegate *delegate = [[StreamDelegate alloc] init];
        
        // Set up the frame received callback
        delegate.frameReceivedCallback = ^(FLIRThermalImage *thermalImage) {
            // Get image dimensions
            int width = [thermalImage getWidth];
            int height = [thermalImage getHeight];
            
            // Create OpenCV mat for visual representation
            cv::Mat frame(height, width, CV_8UC1);
            
            // Use the thermal streamer to get a visualization of the thermal image
            UIImage *image = [m_thermal_streamer getImage];
            if (image) {
                // Convert UIImage to OpenCV Mat
                CGImageRef imageRef = image.CGImage;
                CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageRef);
                CGFloat cols = CGImageGetWidth(imageRef);
                CGFloat rows = CGImageGetHeight(imageRef);
                
                cv::Mat colorMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
                
                CGContextRef contextRef = CGBitmapContextCreate(colorMat.data,
                                                               cols,
                                                               rows,
                                                               8,
                                                               colorMat.step[0],
                                                               colorSpace,
                                                               kCGImageAlphaNoneSkipLast |
                                                               kCGBitmapByteOrderDefault);
                
                CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), imageRef);
                CGContextRelease(contextRef);
                
                // Convert to grayscale
                cv::Mat grayMat;
                cv::cvtColor(colorMat, grayMat, cv::COLOR_RGBA2GRAY);
                
                // Resize if needed
                if (grayMat.rows != height || grayMat.cols != width) {
                    cv::resize(grayMat, frame, cv::Size(width, height));
                } else {
                    grayMat.copyTo(frame);
                }
                
                // Lock the mutex for thread-safe access
                std::lock_guard<std::mutex> lock(m_frame_mutex);
                
                // Update our latest frame
                m_latest_frame = frame.clone();
                m_frame_counter++;
            }
        };
        
        // Set up the error callback
        delegate.errorCallback = ^(NSError *callbackError) {
            NSLog(@"Stream error: %@", callbackError.localizedDescription);
        };
        
        m_stream_delegate = delegate;
        m_stream.delegate = delegate;
        
        // Create thermal streamer
        m_thermal_streamer = [[FLIRThermalStreamer alloc] initWithStream:m_stream];
        [m_thermal_streamer setRenderScale:YES];
        
        // Associate the thermal streamer with the delegate for later use
        objc_setAssociatedObject(delegate, "thermalStreamer", m_thermal_streamer, OBJC_ASSOCIATION_ASSIGN);
        
        // Start the stream with error parameter (matching the example code)
        NSError *error = nil;
        if (![m_stream start:&error]) {
            NSLog(@"Failed to start stream: %@", error.localizedDescription);
            g_lastStatusCode = static_cast<int>(error.code);
            m_stream_delegate = nil;
            m_stream = nil;
            m_thermal_streamer = nil;
            return;
        }
        
        m_is_streaming = true;
        m_frame_counter = 0;
        NSLog(@"Stream started successfully");
    }
}

void FlirCamera::FlirCameraImpl::stopStream() {
    @autoreleasepool {
        if (!m_is_streaming || m_stream == nil) {
            return;
        }
        
        // Stop the stream
        [m_stream stop];
        
        // Release resources
        m_stream_delegate = nil;
        m_stream = nil;
        m_thermal_streamer = nil;
        m_is_streaming = false;
        
        NSLog(@"Stream stopped");
    }
}

void FlirCamera::FlirCameraImpl::playStream() {
    @autoreleasepool {
        if (!m_is_connected || !m_is_streaming) {
            NSLog(@"Cannot play stream - camera not connected or stream not started");
            return;
        }
        
        // Get an image from the thermal streamer
        UIImage *image = [m_thermal_streamer getImage];
        if (image) {
            NSLog(@"Image received from thermal streamer (size: %f x %f)", 
                  image.size.width, image.size.height);
        } else {
            NSLog(@"No image available from thermal streamer");
        }
        
        // Note: In a real UI application, you would display this image in a UIImageView
        NSLog(@"Stream is available for display. Use thermal_streamer.getImage() to get UI image");
    }
}

void FlirCamera::FlirCameraImpl::playStreamCV() {
    if (!m_is_connected || !m_is_streaming) {
        NSLog(@"Cannot play stream with OpenCV - camera not connected or stream not started");
        return;
    }
    
    // Get the latest frame
    auto [frameCounter, frame] = getLatestFrame(0);
    
    if (!frame.has_value()) {
        NSLog(@"No valid frame available to display");
        return;
    }
    
    // In a real application, this would display the frame in an OpenCV window
    // Using cv::imshow or similar. For now, we'll just log that the frame is ready
    NSLog(@"OpenCV frame ready for display (size: %dx%d)", 
          frame.value().cols, frame.value().rows);
}

std::pair<uint64_t, std::optional<cv::Mat>>
FlirCamera::FlirCameraImpl::getLatestFrame(uint64_t lastSeenFrame) {
    // If no new frames since last request, return the same frame counter with no frame
    if (lastSeenFrame >= m_frame_counter) {
        return {m_frame_counter, std::nullopt};
    }
    
    // Lock the mutex for thread-safe access
    std::lock_guard<std::mutex> lock(m_frame_mutex);
    
    // If we have a valid frame, return a copy of it
    if (!m_latest_frame.empty()) {
        return {m_frame_counter, m_latest_frame.clone()};
    }
    
    // No valid frame available
    return {m_frame_counter, std::nullopt};
}

std::optional<std::string> FlirCamera::FlirCameraImpl::getModelName() const {
  // To be implemented
  return std::nullopt;
}

std::optional<double> FlirCamera::FlirCameraImpl::getFrameRate() const {
  // To be implemented
  return std::nullopt;
}

std::optional<netxten::types::FrameSize>
FlirCamera::FlirCameraImpl::getFrameSize() const {
  // To be implemented
  return std::nullopt;
}

bool FlirCamera::FlirCameraImpl::isConnected() const { 
    return m_is_connected; 
}

bool FlirCamera::FlirCameraImpl::isStreaming() const { 
    return m_is_streaming; 
}

// Implementation of the DiscoverCameras methods
std::vector<FLIRIdentity*> FlirCamera::FlirCameraImpl::discoverCameras(
    int communicationInterface, NSTimeInterval timeout) {
  
  std::vector<FLIRIdentity*> discoveredCameras;
  
  @autoreleasepool {
    // Perform camera discovery
    FLIRDiscovery *discovery = [[FLIRDiscovery alloc] init];
    
    // Convert the C++ interface value to Objective-C enum
    FLIRCommunicationInterface interface = FLIRCommunicationInterfaceNetwork;
    if (communicationInterface == FlirCamera::CommunicationInterface::emulator) {
        interface = FLIRCommunicationInterfaceEmulator;
    } else if (communicationInterface == FlirCamera::CommunicationInterface::usb) {
        interface = FLIRCommunicationInterfaceLightning; // Use Lightning for iOS as USB equivalent
    }
    
    __block bool discoveryCompleted = false;
    __block NSMutableArray<FLIRIdentity*> *identities = [NSMutableArray array];
    
    // Setup discovery delegate with multi-camera collection
    DiscoveryDelegate *delegate = [[DiscoveryDelegate alloc] 
        initWithCompletionHandler:^(FLIRIdentity *foundIdentity) {
            // Add the identity to our array
            [identities addObject:foundIdentity];
            
            // Don't set discoveryCompleted - we want to find all cameras
            // until the timeout occurs
        } 
        errorHandler:^(NSString *errorMsg) {
            NSLog(@"Discovery error: %@", errorMsg);
            discoveryCompleted = true;
        }];
    
    discovery.delegate = delegate;
    [discovery start:interface];
    
    // Wait for the discovery timeout period to give time to find multiple cameras
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeout]];
    
    [discovery stop];
    
    // Convert NSArray to std::vector
    for (FLIRIdentity *identity in identities) {
        discoveredCameras.push_back(identity);
    }
    
    if (discoveredCameras.empty()) {
        NSLog(@"No cameras discovered within timeout period");
    } else {
        NSLog(@"Discovered %lu cameras", (unsigned long)discoveredCameras.size());
    }
  }
  
  return discoveredCameras;
}

//============================================================================
// FlirCamera Class Implementation
//============================================================================

FlirCamera::FlirCamera() {
  m_impl = std::make_unique<FlirCamera::FlirCameraImpl>();
}

FlirCamera::~FlirCamera() {
  disconnect();
  m_impl.reset();
}

bool FlirCamera::connect(const ConnectionParameters &params) {
  return m_impl->connect(params);
}

void FlirCamera::disconnect() { m_impl->disconnect(); }

void FlirCamera::autofocus() { m_impl->autofocus(); }

void *FlirCamera::captureSnapshot() { return m_impl->captureSnapshot(); }

void FlirCamera::freeSnapshot(void *snapshot) {
  FlirCameraImpl::freeSnapshot(snapshot);
}

void FlirCamera::printCameraInfo() {
  // To be implemented
}

void FlirCamera::startStream() { m_impl->startStream(); }

void FlirCamera::stopStream() { m_impl->stopStream(); }

void FlirCamera::playStream() { m_impl->playStream(); }

void FlirCamera::playStreamCV() { m_impl->playStreamCV(); }

std::pair<uint64_t, std::optional<cv::Mat>>
FlirCamera::getLatestFrame(uint64_t lastSeenFrame) {
  return m_impl->getLatestFrame(lastSeenFrame);
}

std::optional<std::string> FlirCamera::getModelName() const {
  return m_impl->getModelName();
}

std::optional<double> FlirCamera::getFrameRate() const {
  return m_impl->getFrameRate();
}

std::optional<netxten::types::FrameSize> FlirCamera::getFrameSize() const {
  return m_impl->getFrameSize();
}

bool FlirCamera::isConnected() const { return m_impl->isConnected(); }

bool FlirCamera::isStreaming() const { return m_impl->isStreaming(); }

} // namespace netxten::camera
