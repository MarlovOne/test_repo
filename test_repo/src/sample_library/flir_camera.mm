// flir_camera.mm
#import <Foundation/Foundation.h>
// Import all available headers to be safe
#import <ThermalSDK/ThermalSDK.h>
#import <ThermalSDK/FLIRCamera.h> 
#import <ThermalSDK/FLIRIdentity.h>
#import <ThermalSDK/FLIRDiscovery.h>
#include <test_repo/flir_camera.hpp>
#include <mutex>
#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/highgui/highgui.hpp>

namespace netxten::camera {

// Static variable for status code
static int g_lastStatusCode = 0;

class FlirCamera::FlirCameraImpl {
private:
    // Use exact class names from the SDK
    FLIRCamera* camera;
    id streamDelegate; // Use generic id instead of specific protocol
    dispatch_queue_t queue;
    bool isConnected_;
    bool isStreaming_;
    cv::Mat latestFrame;
    uint64_t frameCounter;
    std::mutex frameMutex;
    
public:
    FlirCameraImpl() 
        : camera(nil)
        , streamDelegate(nil)
        , isConnected_(false)
        , isStreaming_(false)
        , frameCounter(0)
    {
        queue = dispatch_queue_create("com.flir.camera.queue", DISPATCH_QUEUE_SERIAL);
    }
    
    ~FlirCameraImpl() {
        disconnect();
        if (queue) {
            dispatch_release(queue);
            queue = nullptr;
        }
    }
    
    bool connect(const FlirCamera::ConnectionParameters& params) {
        @autoreleasepool {
            NSError* error = nil;
            
            // Initialize the FLIR SDK - adapt to available API
            FLIRThermalSDK* sdk = [FLIRThermalSDK sharedInstance];
            if ([sdk respondsToSelector:@selector(initializeWithLicense:error:)]) {
                [sdk initializeWithLicense:nil error:&error];
            } else if ([sdk respondsToSelector:@selector(initializeWithError:)]) {
                [sdk performSelector:@selector(initializeWithError:) withObject:&error];
            } else {
                NSLog(@"Unable to find initialization method in FLIR SDK");
                return false;
            }
            
            if (error) {
                NSLog(@"Failed to initialize ThermalSDK: %@", error.localizedDescription);
                g_lastStatusCode = static_cast<int>(error.code);
                return false;
            }
            
            // Create discovery
            FLIRDiscovery* discovery = [[FLIRDiscovery alloc] init];
            
            // Try to discover cameras using available methods
            NSArray* cameras = nil;
            
            if ([discovery respondsToSelector:@selector(discoverCameras:)]) {
                cameras = [discovery discoverCameras:&error];
            }
            
            if (!cameras || cameras.count == 0) {
                NSLog(@"No cameras found");
                return false;
            }
            
            // Try to create camera with the first discovered device
            id identity = cameras.firstObject;
            
            if ([FLIRCamera respondsToSelector:@selector(cameraWithIdentity:error:)]) {
                camera = [FLIRCamera cameraWithIdentity:identity error:&error];
            } else {
                camera = [[FLIRCamera alloc] init];
            }
            
            if (!camera || error) {
                NSLog(@"Failed to create camera: %@", error.localizedDescription);
                return false;
            }
            
            // Connect to camera
            if ([camera respondsToSelector:@selector(connect:)]) {
                [camera connect:&error];
            }
            
            if (error) {
                NSLog(@"Failed to connect: %@", error.localizedDescription);
                return false;
            }
            
            isConnected_ = true;
            m_conn_params = params;
            
            return true;
        }
    }
    
    void disconnect() {
        @autoreleasepool {
            if (isStreaming_) {
                stopStream();
            }
            
            if (camera) {
                NSError* error = nil;
                [camera disconnect:&error];
                if (error) {
                    NSLog(@"Error disconnecting: %@", error.localizedDescription);
                    g_lastStatusCode = static_cast<int>(error.code);
                }
                camera = nil;
            }
            
            isConnected_ = false;
        }
    }
    
    void startStream() {
        if (!isConnected_ || isStreaming_) return;
        
        @autoreleasepool {
            NSError* error = nil;
            
            // Configure streaming parameters if available
            if (m_stream_params.has_value()) {
                FLIRStreamControl* streamControl = camera.streamControl;
                streamControl.width = m_stream_params->width;
                streamControl.height = m_stream_params->height;
                streamControl.frameRate = m_stream_params->frame_rate;
                
                // Apply settings
                [streamControl applySettings:&error];
                if (error) {
                    NSLog(@"Failed to apply stream settings: %@", error.localizedDescription);
                    g_lastStatusCode = static_cast<int>(error.code);
                    return;
                }
            }
            
            // Create stream delegate if needed
            if (!streamDelegate) {
                streamDelegate = [[FLIRDataHandler alloc] initWithBlock:^(FLIRThermalImageFile* imageFile) {
                    // Handler implementation
                }];
            }
            
            // Start streaming
            [camera startStreamingWithDelegate:streamDelegate error:&error];
            if (error) {
                NSLog(@"Failed to start stream: %@", error.localizedDescription);
                g_lastStatusCode = static_cast<int>(error.code);
                return;
            }
            
            isStreaming_ = true;
        }
    }
    
    void stopStream() {
        if (!isStreaming_) return;
        
        @autoreleasepool {
            NSError* error = nil;
            [camera stopStream:&error];
            if (error) {
                NSLog(@"Error stopping stream: %@", error.localizedDescription);
                g_lastStatusCode = static_cast<int>(error.code);
            }
            isStreaming_ = false;
        }
    }
    
    void* captureSnapshot() {
        if (!isConnected_) return nullptr;
        
        @autoreleasepool {
            NSError* error = nil;
            FLIRThermalImageFile* imageFile = [camera capturePhoto:&error];
            if (error || !imageFile) {
                NSLog(@"Failed to capture snapshot: %@", error.localizedDescription);
                g_lastStatusCode = error ? static_cast<int>(error.code) : -1;
                return nullptr;
            }
            
            // Retain the image for later use
            void* ptr = (__bridge_retained void*)imageFile;
            return ptr;
        }
    }
    
    static void freeSnapshot(void* snapshot) {
        if (!snapshot) return;
        
        @autoreleasepool {
            FLIRThermalImageFile* imageFile = (__bridge_transfer FLIRThermalImageFile*)snapshot;
            // The bridge_transfer will handle releasing the object
        }
    }
    
    std::pair<uint64_t, std::optional<cv::Mat>> getLatestFrame(uint64_t lastSeenFrame) {
        std::lock_guard<std::mutex> lock(frameMutex);
        if (frameCounter > lastSeenFrame && !latestFrame.empty()) {
            cv::Mat copy;
            latestFrame.copyTo(copy);
            return {frameCounter, copy};
        }
        return {lastSeenFrame, std::nullopt};
    }
    
    void autofocus() {
        if (!isConnected_) return;
        
        @autoreleasepool {
            NSError* error = nil;
            [camera.focusControl runAutofocus:&error];
            if (error) {
                NSLog(@"Autofocus failed: %@", error.localizedDescription);
                g_lastStatusCode = static_cast<int>(error.code);
            }
        }
    }
    
    void printCameraInfo() {
        if (!isConnected_) return;
        
        @autoreleasepool {
            FLIRCameraInfo* info = camera.cameraInfo;
            NSLog(@"Model: %@", info.modelName);
            NSLog(@"Serial: %@", info.serialNumber);
            NSLog(@"Firmware: %@", info.firmwareVersion);
        }
    }
    
    void playStream() {
        if (!isStreaming_) {
            startStream();
        }
        
        // Note: This is a simplified implementation
        // In a real app, you would integrate with iOS UI components
        NSLog(@"Native stream playback started - integrate with UIKit views");
    }
    
    void playStreamCV() {
        if (!isStreaming_) {
            startStream();
        }
        
        // This is just a placeholder since OpenCV window management
        // works differently on iOS compared to desktop platforms
        NSLog(@"OpenCV stream playback not implemented for iOS");
    }
    
    std::optional<std::string> getModelName() const {
        if (!camera) return std::nullopt;
        
        @autoreleasepool {
            NSString* modelName = camera.modelName;
            if (modelName) {
                return std::optional<std::string>([modelName UTF8String]);
            }
            return std::optional<std::string>();
        }
    }
    
    std::optional<double> getFrameRate() const {
        if (!camera) return std::nullopt;
        
        @autoreleasepool {
            return camera.streamControl.frameRate;
        }
    }
    
    std::optional<netxten::types::FrameSize> getFrameSize() const {
        if (!camera) return std::nullopt;
        
        @autoreleasepool {
            return netxten::types::FrameSize{
                static_cast<int>(camera.streamControl.width),
                static_cast<int>(camera.streamControl.height)
            };
        }
    }
    
    bool isConnected() const { return isConnected_; }
    bool isStreaming() const { return isStreaming_; }
    
    void setStreamParameters(const FlirCamera::StreamParameters& params) {
        m_stream_params = params;
    }
    
    FlirCamera::ConnectionParameters m_conn_params;
    std::optional<FlirCamera::StreamParameters> m_stream_params;
};

// Implementation of the public FlirCamera class methods
FlirCamera::FlirCamera() : m_impl(std::make_unique<FlirCameraImpl>()) {}

FlirCamera::~FlirCamera() = default;

bool FlirCamera::connect(const ConnectionParameters& params) {
    m_conn_params = params;
    return m_impl->connect(params);
}

void FlirCamera::disconnect() {
    m_impl->disconnect();
}

void FlirCamera::startStream() {
    if (m_stream_params.has_value()) {
        m_impl->setStreamParameters(*m_stream_params);
    }
    m_impl->startStream();
}

void FlirCamera::stopStream() {
    m_impl->stopStream();
}

void FlirCamera::autofocus() {
    m_impl->autofocus();
}

void* FlirCamera::captureSnapshot() {
    return m_impl->captureSnapshot();
}

void FlirCamera::freeSnapshot(void* snapshot) {
    FlirCameraImpl::freeSnapshot(snapshot);
}

void FlirCamera::printCameraInfo() {
    m_impl->printCameraInfo();
}

void FlirCamera::playStream() {
    m_impl->playStream();
}

void FlirCamera::playStreamCV() {
    m_impl->playStreamCV();
}

std::pair<uint64_t, std::optional<cv::Mat>> FlirCamera::getLatestFrame(uint64_t lastSeenFrame) {
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

bool FlirCamera::isConnected() const {
    return m_impl->isConnected();
}

bool FlirCamera::isStreaming() const {
    return m_impl->isStreaming();
}

void FlirCamera::check_acs(bool throw_on_error) {
    if (g_lastStatusCode != 0) {
        if (throw_on_error) {
            throw std::runtime_error("FLIR SDK error: " + std::to_string(g_lastStatusCode));
        }
    }
}

} // namespace netxten::camera