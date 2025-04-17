// flir_camera.mm
#import <Foundation/Foundation.h>
#import <ThermalSDK/ThermalSDK.h>
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
    FLIRThermalCamera* camera;
    FLIRStreamDelegate* streamDelegate;
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
            
            // Initialize the FLIR ThermalSDK
            [FLIRThermalSDK initializeWithError:&error];
            if (error) {
                NSLog(@"Failed to initialize ThermalSDK: %@", error.localizedDescription);
                g_lastStatusCode = static_cast<int>(error.code);
                return false;
            }
            
            // Create camera discovery session
            FLIRDiscovery* discovery = [[FLIRDiscovery alloc] init];
            
            // If IP is specified, connect directly
            if (!params.ip.empty()) {
                NSURL* cameraURL = [NSURL URLWithString:[NSString stringWithUTF8String:params.ip.c_str()]];
                camera = [FLIRThermalCamera cameraWithURL:cameraURL error:&error];
            } else {
                // Discover cameras based on communication interface
                FLIRCommunicationInterface commInterface;
                switch (params.communication_interface) {
                    case FlirCamera::usb:
                        commInterface = FLIRCommunicationInterfaceUSB;
                        break;
                    case FlirCamera::network:
                        commInterface = FLIRCommunicationInterfaceNetwork;
                        break;
                    case FlirCamera::emulator:
                        commInterface = FLIRCommunicationInterfaceSimulator;
                        break;
                    default:
                        commInterface = FLIRCommunicationInterfaceSimulator;
                        break;
                }
                
                NSArray<FLIRIdentity*>* cameras = [discovery discoverCamerasWithInterface:commInterface error:&error];
                if (cameras.count > 0) {
                    camera = [FLIRThermalCamera cameraWithIdentity:cameras[0] error:&error];
                }
            }
            
            if (!camera || error) {
                NSLog(@"Failed to connect to camera: %@", error ? error.localizedDescription : @"No camera found");
                g_lastStatusCode = error ? static_cast<int>(error.code) : -1;
                return false;
            }
            
            // Connect to the camera
            [camera connect:&error];
            if (error) {
                NSLog(@"Failed to connect: %@", error.localizedDescription);
                g_lastStatusCode = static_cast<int>(error.code);
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
                streamDelegate = [[FLIRStreamDelegate alloc] init];
                __block FlirCameraImpl* weakSelf = this;
                streamDelegate.frameHandler = ^(FLIRThermalImage* image) {
                    if (!image) return;
                    
                    // Convert FLIR image to cv::Mat
                    NSData* data = [image.thermalPixels data];
                    cv::Mat rawFrame(image.height, image.width, CV_16UC1, (void*)data.bytes);
                    
                    // Store the frame
                    std::lock_guard<std::mutex> lock(weakSelf->frameMutex);
                    rawFrame.copyTo(weakSelf->latestFrame);
                    weakSelf->frameCounter++;
                };
            }
            
            // Start streaming
            [camera startStreamWithDelegate:streamDelegate error:&error];
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
            FLIRThermalImage* image = [camera captureImage:&error];
            if (error || !image) {
                NSLog(@"Failed to capture snapshot: %@", error.localizedDescription);
                g_lastStatusCode = error ? static_cast<int>(error.code) : -1;
                return nullptr;
            }
            
            // Retain the image for later use
            [image retain];
            return (__bridge_retained void*)image;
        }
    }
    
    static void freeSnapshot(void* snapshot) {
        if (!snapshot) return;
        
        @autoreleasepool {
            FLIRThermalImage* image = (__bridge_transfer FLIRThermalImage*)snapshot;
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
            NSString* modelName = camera.cameraInfo.modelName;
            return modelName ? std::string(modelName.UTF8String) : std::nullopt;
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