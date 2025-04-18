// FLIR Camera implementation for iOS using Objective-C++
#import <Foundation/Foundation.h>
// Import FLIR SDK headers for iOS
#import <ThermalSDK/ThermalSDK.h>

// C++ standard library and OpenCV
#include <mutex>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <optional>
#include <test_repo/flir_camera.hpp>

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
  // To be implemented
}

void *FlirCamera::FlirCameraImpl::captureSnapshot() {
  // To be implemented
  return nullptr;
}

void FlirCamera::FlirCameraImpl::freeSnapshot(void *snapshot) {
  // To be implemented
}

void FlirCamera::FlirCameraImpl::startStream() {
  // To be implemented
}

void FlirCamera::FlirCameraImpl::stopStream() {
  // To be implemented
}

void FlirCamera::FlirCameraImpl::playStream() {
  // To be implemented
}

void FlirCamera::FlirCameraImpl::playStreamCV() {
  // To be implemented
}

std::pair<uint64_t, std::optional<cv::Mat>>
FlirCamera::FlirCameraImpl::getLatestFrame(uint64_t lastSeenFrame) {
  // To be implemented
  return {lastSeenFrame, std::nullopt};
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
