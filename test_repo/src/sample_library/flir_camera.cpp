#include <test_repo/flir_camera.hpp>

#include <cstdlib>
#include <cstring>
#include <spdlog/spdlog.h>
#include <stdexcept>

extern "C" {
#include <acs/acs.h>
#include <acs/camera.h>
#include <acs/discovery.h>
#include <acs/renderer.h>
#include <acs/thermal_image.h>
#include <acs/utility.h>
}

using namespace netxten::camera;

/**
 * @brief Private implementation class for FlirCamera. Manages low-level interactions with
 * FLIR SDK.
 */
class FlirCamera::FlirCameraImpl
{
public:
  /** @brief Callback invoked when a new camera is discovered. */
  static void onCameraFound(const ACS_DiscoveredCamera *discoveredCamera, void *context);

  /** @brief Callback invoked when an error occurs during camera discovery. */
  static void onDiscoveryError(ACS_CommunicationInterface cif, ACS_Error error, void *context);

  /** @brief Callback invoked when a previously discovered camera is lost. */
  static void onCameraLost(const ACS_Identity *identity, void *context);

  /** @brief Callback invoked when the camera discovery process completes. */
  static void onDiscoveryFinished(ACS_CommunicationInterface interface, void *context);

  /** @brief Callback invoked upon disconnection from a camera. */
  static void onDisconnect(ACS_Error error, void *context);

  /** @brief Callback invoked when file import from the camera completes successfully. */
  static void onImportComplete(void *context);

  /** @brief Callback invoked when an error occurs during file import from the camera. */
  static void onImportError(ACS_Error error, void *context);

  /** @brief Callback for tracking file import progress from the camera. */
  static void onImportProgress(const ACS_FileReference *file, long long current, long long total, void *context);

  /** @brief Callback invoked each time an image is received from the camera stream. */
  static void onImageReceived(unsigned long *counter);

  /** @brief Callback invoked when a general error occurs. */
  static void onError(ACS_Error error, void *context);

  /** @brief Utility function to print camera stream information. */
  static void printStreamInformation(ACS_Camera *camera);

  /** @brief Finds and returns the thermal stream from a connected camera, if available.
   */
  static ACS_Stream *findThermalStream(ACS_Camera *camera);

  /** @brief Finds and returns the visual stream from a connected camera, if available. */
  static ACS_Stream *findVisualStream(ACS_Camera *camera);

  /** @brief Helper function used to process thermal images. */
  static void withThermalImageHelper(ACS_ThermalImage *thermalImage, void *context);

  /** @brief Checks ACS SDK error status and optionally throws an exception. */
  static void checkACSError(ACS_Error error, bool throw_on_error = false);

  /**
   * @brief Discovers a camera using the specified communication interface.
   * @param communication_interface The interface to perform discovery on (default:
   * network).
   * @return Pointer to discovered camera identity.
   */
  static ACS_Identity *discoverCamera(
    ACS_CommunicationInterface_ communication_interface = ACS_CommunicationInterface_network);

  /**
   * @brief Opens a thermal image from the given file path.
   * @param path File path to the thermal image.
   * @return Pointer to the opened thermal image.
   */
  static ACS_ThermalImage *openThermalImage(const char *path);

  /**
   * @brief Converts ACS_ImageBuffer to OpenCV Mat format.
   * @param imageBuffer Pointer to ACS_ImageBuffer containing the image data.
   * @param stream_params Optional stream parameters describing the image buffer format.
   * @return Converted cv::Mat image.
   */
  static cv::Mat convertACSBufferToCVMat(const ACS_ImageBuffer *imageBuffer,
    std::optional<StreamParameters> &stream_params);

  /**
   * @brief Converts ACS_CommunicationInterface enum to human-readable string.
   * @param comm Communication interface enum value.
   * @return Corresponding descriptive string.
   */
  static constexpr auto commInterfaceToString(ACS_CommunicationInterface_ comm)
  {
    switch (comm) {
    case ACS_CommunicationInterface_usb:
      return "USB";
    case ACS_CommunicationInterface_network:
      return "Network";
    case ACS_CommunicationInterface_emulator:
      return "Emulator";
    default:
      return "Unknown";
    }
  };

  /**
   * @brief Context structure for streaming callback functions.
   */
  typedef struct StreamingCallbackContext_
  {
    std::optional<std::string> model_name = std::nullopt;///< Model name of the camera.
  } StreamingCallbackContext;

  /**
   * @brief Context structure for camera discovery.
   */
  struct DiscoveryContext
  {
    bool futureAlreadySet;///< Indicates if discovery future is already set.
    ACS_Future *futureIdentity;///< Future object for asynchronous camera discovery.
  };

  //==================== Member Functions =========================

  /**
   * @brief Captures a snapshot from the connected thermal camera.
   * @return Pointer to captured ACS_ThermalImage.
   */
  ACS_ThermalImage *takeSnapshot() const;

  /**
   * @brief Captures a temporary snapshot from the thermal camera for internal processing.
   * @return Pointer to temporary ACS_ThermalImage.
   */
  ACS_ThermalImage *takeTemporarySnapshot() const;

  //====================== Data Members ===========================

  ACS_Camera *m_camera = nullptr;///< Pointer to the connected ACS camera instance.
  ACS_RemoteControl *m_remote_control = nullptr;///< Remote control interface for camera operations.
  ACS_Stream *m_stream = nullptr;///< Pointer to the active stream object.
  ACS_Streamer *m_streamer = nullptr;///< Streamer managing the active stream.
  ACS_ThermalStreamer *m_thermal_streamer = nullptr;///< Thermal streamer for thermal image data.
  ACS_Renderer *m_renderer = nullptr;///< Renderer object for stream image rendering.
  StreamingCallbackContext m_stream_context = {};///< Context used during streaming callbacks.
};


void FlirCamera::check_acs(bool throw_onError)
{
  ACS_Error error = ACS_getLastError();
  FlirCamera::Impl::checkACSError(error, throw_onError);
}

void FlirCamera::FlirCameraImpl::checkACSError(ACS_Error error, bool throw_on_error)
{
  // If error.code is nonzero, an error occurred.
  if (error.code == 0) { return; }

  ACS_String *errorString = ACS_getErrorMessage(error);
  if (errorString == nullptr) {
    spdlog::error("ACS failed: {}, details: {}", error.code, ACS_getLastErrorMessage());
    if (throw_on_error) { throw std::runtime_error(ACS_getLastErrorMessage()); }
    return;
  }

  spdlog::error("ACS failed: {}, details: {}", ACS_String_get(errorString), ACS_getLastErrorMessage());
  if (throw_on_error) {
    throw std::runtime_error("Throwing due to ACS error: " + std::string(ACS_String_get(errorString)));
  }
  ACS_String_free(errorString);
}

//============================================================================
// FlirCamera Class Implementation
//============================================================================

FlirCamera::FlirCamera()
{
  spdlog::info("FlirCamera object created");
  m_impl = std::make_unique<FlirCamera::FlirCameraImpl>();
}

FlirCamera::~FlirCamera()
{
  spdlog::info("FlirCamera object destroyed");
  disconnect();
  m_impl.reset();
}

bool FlirCamera::connect(const ConnectionParameters &params)
{
  spdlog::info("Connecting to camera...");
  ACS_Identity *identity = params.ip.empty() ? FlirCamera::Impl::discoverCamera(
                             static_cast<ACS_CommunicationInterface_>(params.communication_interface))
                                             : ACS_Identity_fromIpAddress(params.ip.c_str());
  if (identity == nullptr) {
    spdlog::error("Could not discover any camera");
    disconnect();
    return false;
  }
  spdlog::info("Camera identity discovered!");

  // Allocate and initialize the camera.
  spdlog::info("Allocating ACS camera...");
  m_impl->m_camera = ACS_Camera_alloc();
  check_acs(true);
  spdlog::info("ACS camera allocated!");

  if (params.authenticate_with_camera) {

    // Authenticate with the camera. Adjust certificate parameters as needed.
    spdlog::info("Authenticating with camera...");
    ACS_AuthenticationResponse response = ACS_Camera_authenticate(m_impl->m_camera,
      identity,
      params.certificate_path.c_str(),
      params.certificate_name.c_str(),
      params.common_name.c_str(),
      ACS_AUTHENTICATE_USE_DEFAULT_TIMEOUT);
    check_acs();

    if (response.authenticationStatus != ACS_AuthenticationStatus_approved) {
      spdlog::error(
        "Unable to authenticate with camera – please check that the certificate is "
        "approved in the camera's UI");
      spdlog::error("Authentication status: {}", response.authenticationStatus);
      spdlog::error("Trying to continue with the connection anyway...");
      // Depending on your requirements, you might return false here.
      // disconnect();
      // return false;
    } else {
      spdlog::info("Successfully authenticated with camera");
    }

  } else {
    spdlog::info("Skipping camera authentication");
  }

  spdlog::info("Connecting to camera...");
  ACS_Error error =
    ACS_Camera_connect(m_impl->m_camera, identity, nullptr, FlirCamera::Impl::onDisconnect, nullptr, nullptr);
  FlirCamera::FlirCameraImpl::checkACSError(error, true);
  ACS_Identity_free(identity);

  spdlog::info("Connected to camera!");
  spdlog::info("Camera connected: {}", ACS_Camera_isConnected(m_impl->m_camera));

  // Retrieve the remote control interface.
  spdlog::info("Retrieving remote control interface...");
  m_impl->m_remote_control = ACS_Camera_getRemoteControl(m_impl->m_camera);
  if (m_impl->m_remote_control == nullptr) {
    spdlog::error("Camera does not support remote control");
    // disconnect();
    // return false;
  }

  spdlog::info("Printing stream information...");
  FlirCamera::Impl::printStreamInformation(m_impl->m_camera);

  if (params.colorized_streaming) {
    spdlog::info("Colorized streaming selected");
    m_impl->m_stream = FlirCamera::Impl::findVisualStream(m_impl->m_camera);
  } else {
    spdlog::info("Thermal streaming selected");
    m_impl->m_stream = FlirCamera::Impl::findThermalStream(m_impl->m_camera);
  }

  if (m_impl->m_stream == nullptr) {
    spdlog::error("No thermal or visual stream found");
    disconnect();
    return false;
  }

  // Get the streamer
  if (params.colorized_streaming) {
    spdlog::info("Allocating visual streamer...");
    m_impl->m_streamer = ACS_VisualStreamer_asStreamer(ACS_VisualStreamer_alloc(m_impl->m_stream));
  } else {
    spdlog::info("Allocating thermal streamer...");
    m_impl->m_thermal_streamer = ACS_ThermalStreamer_alloc(m_impl->m_stream);
    m_impl->m_streamer = ACS_ThermalStreamer_asStreamer(m_impl->m_thermal_streamer);
  }
  check_acs(true);

  // Setup renderer
  spdlog::info("Allocating renderer...");
  m_impl->m_renderer = ACS_Streamer_asRenderer(m_impl->m_streamer);
  ACS_Renderer_setOutputColorSpace(m_impl->m_renderer, ACS_ColorSpaceType_rgb);
  check_acs(true);

  spdlog::info("Camera connected successfully!");
  m_conn_params = params;
  return true;
}

ACS_Stream *FlirCamera::FlirCameraImpl::findThermalStream(ACS_Camera *camera)
{
  for (size_t i = 0; i < ACS_Camera_getStreamCount(camera); ++i) {
    ACS_Stream *stream = ACS_Camera_getStream(camera, i);
    spdlog::info("found stream id: {}", i);
    if (ACS_Stream_isThermal(stream)) {
      spdlog::info("found thermal stream");
      return stream;
    }
  }
  return nullptr;
}

ACS_Stream *FlirCamera::FlirCameraImpl::findVisualStream(ACS_Camera *camera)
{
  for (size_t i = 0; i < ACS_Camera_getStreamCount(camera); ++i) {
    ACS_Stream *stream = ACS_Camera_getStream(camera, i);
    spdlog::info("found stream id: {}", i);
    if (!ACS_Stream_isThermal(stream)) {
      spdlog::info("found visual stream");
      return stream;
    }
  }
  return nullptr;
}

void FlirCamera::disconnect()
{
  spdlog::info("Disconnecting from camera...");

  if (m_impl->m_camera != nullptr) {
    spdlog::info("Freeing camera...");
    ACS_Camera_free(m_impl->m_camera);
    m_impl->m_camera = nullptr;
  }

  if (m_impl->m_remote_control != nullptr) {
    spdlog::info("Freeing remote control...");
    m_impl->m_remote_control = nullptr;
  }

  if (m_impl->m_streamer != nullptr) {
    spdlog::info("Freeing streamer...");
    ACS_Streamer_free(m_impl->m_streamer);
    // ACS_ThermalStreamer_free(m_thermal_streamer);
    m_impl->m_stream = nullptr;
    m_impl->m_streamer = nullptr;
    m_impl->m_thermal_streamer = nullptr;
    m_impl->m_renderer = nullptr;
  }
}

void FlirCamera::FlirCameraImpl::onImageReceived(unsigned long *counter) { (*counter)++; }

void FlirCamera::FlirCameraImpl::onError(ACS_Error error, void *context)
{
  // Handle camera stream error
  (void)context;
  if (ACS_getErrorCondition(error) != ACS_ERR_NUC_IN_PROGRESS) { FlirCamera::Impl::checkACSError(error, true); }
}

void FlirCamera::stopStream()
{
  if (m_impl->m_streamer == nullptr) {
    spdlog::error("Streamer not initialized, cannot stop stream");
    return;
  }

  if (!m_streaming) {
    spdlog::error("Stream not started, cannot stop stream");
    return;
  }

  spdlog::info("Stopping stream...");
  ACS_Stream_stop(m_impl->m_stream);
  check_acs(true);
  m_streaming = false;
  m_stream_params = std::nullopt;
  m_callbacks_received = 0;
  m_impl->m_stream_context = {};
  m_previous_frame = std::nullopt;
  spdlog::info("Stream stopped!");
}

void FlirCamera::startStream()
{
  if (m_impl->m_streamer == nullptr) {
    spdlog::error("Streamer not initialized, cannot start stream");
    return;
  }

  spdlog::info("Starting stream...");
  m_callbacks_received = 0;
  // Start the stream! This involves network requests to the camera's stream server
  ACS_Stream_start(m_impl->m_stream,
    (ACS_OnImageReceived)FlirCamera::Impl::onImageReceived,
    FlirCamera::Impl::onError,
    (ACS_CallbackContext){ .context = &m_callbacks_received });

  check_acs(true);
  m_streaming = true;

  // Get the frame to initialize the stream parameters
  int i = 0;
  while (!m_stream_params.has_value() && i < 5) {
    spdlog::info("Waiting for stream parameters...");
    getLatestFrame(i);
    i++;

    // sleep for a bit to avoid busy waiting
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
  }

  if (!m_stream_params.has_value()) {
    spdlog::error("Failed to get stream parameters");
    // TODO(lmark): Do something at this point
  }

  spdlog::info("Stream is up and running!");
}

void FlirCamera::FlirCameraImpl::withThermalImageHelper(ACS_ThermalImage *thermalImage, void *context)
{
  auto *streamContext = reinterpret_cast<FlirCamera::Impl::StreamingCallbackContext *>(context);

  if (thermalImage != nullptr) {
    ACS_ThermalImage_setPalettePreset(thermalImage, ACS_PalettePreset_iron);

    if (!streamContext->model_name.has_value()) {
      ACS_Image_CameraInformation *camInfo = ACS_ThermalImage_getCameraInformation(thermalImage);

      if (camInfo != nullptr) {
        streamContext->model_name = ACS_Image_CameraInformation_getModelName(camInfo);
        printf("Model Name: %s\n", streamContext->model_name.value().c_str());
        ACS_Image_CameraInformation_free(camInfo);
      }
    }
  }
}

std::optional<std::string> FlirCamera::getModelName() const
{
  if (m_impl == nullptr) {
    spdlog::error("FlirCameraImpl is null, cannot get model name");
    return std::nullopt;
  }

  if (m_impl->m_stream_context.model_name.has_value()) {
    return m_impl->m_stream_context.model_name.value();
  } else {
    spdlog::error("Model name not set, cannot get model name");
    return std::nullopt;
  }
}

std::optional<netxten::types::FrameSize> FlirCamera::getFrameSize() const
{
  if (m_stream_params.has_value()) {
    return netxten::types::FrameSize{ static_cast<size_t>(m_stream_params->height),
      static_cast<size_t>(m_stream_params->width) };
  } else {
    spdlog::error("Stream parameters not set, cannot get frame size");
    return std::nullopt;
  }
}

std::optional<double> FlirCamera::getFrameRate() const
{
  if (m_stream_params.has_value()) {
    return m_stream_params->frame_rate;
  } else {
    spdlog::error("Stream parameters not set, cannot get frame rate");
    return std::nullopt;
  }
}

bool FlirCamera::isConnected() const
{
  if (m_impl == nullptr) {
    spdlog::error("FlirCameraImpl is null, cannot check connection");
    return false;
  }

  if (m_impl->m_camera == nullptr) {
    spdlog::error("Camera is null, cannot check connection");
    return false;
  }

  return ACS_Camera_isConnected(m_impl->m_camera);
}

bool FlirCamera::isStreaming() const { return m_streaming; }

std::pair<uint64_t, std::optional<cv::Mat>> FlirCamera::getLatestFrame(uint64_t lastSeenFrame)
{
  uint64_t newFrame = 0;
  if (m_callbacks_received > lastSeenFrame) {
    newFrame = m_callbacks_received;
    // printf("Rendering frame nr: %lu\n", renderFrame);
  } else {
    // We don't have a new frame yet, so just wait for the next one
    return { newFrame, m_previous_frame };
  }

  // Poll image from camera
  ACS_Renderer_update(m_impl->m_renderer);
  check_acs();
  const ACS_ImageBuffer *image = ACS_Renderer_getImage(m_impl->m_renderer);

  // Skip if no valid framedata.
  if (image == nullptr) {
    spdlog::info("No valid frame data, skipping...");
    return { newFrame, m_previous_frame };
  }

  if (!m_conn_params.colorized_streaming) {
    // Process the thermal image as needed
    ACS_ThermalStreamer_withThermalImage(
      m_impl->m_thermal_streamer, FlirCamera::FlirCameraImpl::withThermalImageHelper, &m_impl->m_stream_context);
  }

  m_previous_frame = FlirCamera::Impl::convertACSBufferToCVMat(image, m_stream_params);
  return { newFrame, m_previous_frame };
}

void FlirCamera::playStreamCV()
{

  if (m_impl->m_streamer == nullptr) {
    spdlog::error("Streamer not initialized, cannot play stream");
    return;
  }

  if (!m_streaming) {
    spdlog::error("Stream not started, cannot play stream");
    return;
  }

  // OpenCV window for visualization
  const char *cvWindowName = "OpenCV FLIR Stream";
  cv::namedWindow(cvWindowName, cv::WINDOW_NORMAL);
  unsigned long renderFrame = 0;

  while (true) {
    auto result = getLatestFrame(renderFrame);
    if (!result.second.has_value() || result.second->empty()) { continue; }

    renderFrame = result.first;
    // Display using OpenCV
    cv::imshow(cvWindowName, result.second.value());
    if (cv::waitKey(1) == 27) {// Exit if ESC pressed
      spdlog::info("ESC pressed, exiting loop...");
      break;
    }
  }
  cv::destroyAllWindows();
}

void FlirCamera::playStream()
{
  if (m_impl->m_streamer == nullptr) {
    spdlog::error("Streamer not initialized, cannot play stream");
    return;
  }

  if (!m_streaming) {
    spdlog::error("Stream not started, cannot play stream");
    return;
  }

  // Create a window and run the render loop
  ACS_DebugImageWindow *window = ACS_DebugImageWindow_alloc("C stream sample");
  unsigned long renderFrame = 0;

  // OpenCV window for visualization
  const char *cvWindowName = "OpenCV FLIR Stream";
  cv::namedWindow(cvWindowName, cv::WINDOW_NORMAL);

  while (ACS_DebugImageWindow_poll(window)) {
    // check if we got a new frame
    if (m_callbacks_received > renderFrame) {
      renderFrame = m_callbacks_received;
      // printf("Rendering frame nr: %lu\n", renderFrame);
    } else {
      // We don't have a new frame yet, so just wait for the next one
      continue;
    }

    // Poll image from camera
    ACS_Renderer_update(m_impl->m_renderer);
    check_acs();

    const ACS_ImageBuffer *image = ACS_Renderer_getImage(m_impl->m_renderer);

    // Skip if no valid framedata.
    if (!image) {
      spdlog::info("No valid frame data, skipping...");
      continue;
    }

    cv::Mat cvImage = FlirCamera::Impl::convertACSBufferToCVMat(image, m_stream_params);
    if (cvImage.empty()) {
      spdlog::warn("cvImage is empty, skipping visualization.");
      continue;
    }

    // Display using OpenCV
    cv::imshow(cvWindowName, cvImage);
    if (cv::waitKey(1) == 27) {// Exit if ESC pressed
      spdlog::info("ESC pressed, exiting loop...");
      break;
    }


    if (!m_conn_params.colorized_streaming) {
      // Process the thermal image as needed
      ACS_ThermalStreamer_withThermalImage(
        m_impl->m_thermal_streamer, FlirCamera::Impl::withThermalImageHelper, &m_impl->m_stream_context);
    }

    // Display the received image on screen
    ACS_DebugImageWindow_update(window, image);
    check_acs();
  }
  check_acs(true);

  spdlog::info("Stopping after {} frames", m_callbacks_received);
  spdlog::info("Freeing window...");
  ACS_DebugImageWindow_free(window);
}

void FlirCamera::autofocus()
{
  if (m_impl->m_remote_control == nullptr) {
    spdlog::error("Remote control not initialized, cannot autofocus");
    return;
  }
  spdlog::info("[autofocus] Triggering autofocus...");
  ACS_Remote_Focus_autofocus_executeSync(m_impl->m_remote_control);
  check_acs();
  spdlog::info("[autofocus] Autofocus complete!");
}

void *FlirCamera::captureSnapshot()
{
  spdlog::info("[captureSnapshot] Capturing snapshot...");
  if (!ACS_Camera_isConnected(m_impl->m_camera)) {
    spdlog::error("[captureSnapshot] Camera is not connected");
    return nullptr;
  }

  ACS_ThermalImage *image = m_impl->takeSnapshot();
  if (image == nullptr) {
    spdlog::info("[captureSnapshot] Failed to capture snapshot, trying temporary snapshot...");
    image = m_impl->takeTemporarySnapshot();
  }

  if (image == nullptr) {
    spdlog::error("[captureSnapshot] Failed to capture snapshot");
    throw std::runtime_error("Failed to capture snapshot");
  }

  spdlog::info("[captureSnapshot] Snapshot captured");
  return image;
}

void FlirCamera::freeSnapshot(void *snapshot)
{
  if (snapshot == nullptr) {
    spdlog::warn("Snapshot is null, nothing to free");
    return;
  }

  spdlog::info("Freeing snapshot");
  ACS_ThermalImage_free(reinterpret_cast<ACS_ThermalImage *>(snapshot));
  spdlog::info("Snapshot freed");
}

void FlirCamera::printCameraInfo()
{
  // For demonstration, capture a snapshot and print camera info.
  ACS_ThermalImage *imgPtr = reinterpret_cast<ACS_ThermalImage *>(captureSnapshot());
  ACS_Image_CameraInformation *info = ACS_ThermalImage_getCameraInformation(imgPtr);
  if (info != nullptr) {
    spdlog::info("Model Name: {}", ACS_Image_CameraInformation_getModelName(info));
    spdlog::info("Lens: {}", ACS_Image_CameraInformation_getLens(info));
    spdlog::info("Serial Number: {}", ACS_Image_CameraInformation_getSerialNumber(info));
    ACS_Image_CameraInformation_free(info);
  }
}

//============================================================================
// Discovery and Snapshot Helpers
//============================================================================


ACS_Identity *FlirCamera::FlirCameraImpl::discoverCamera(ACS_CommunicationInterface_ communication_interface)
{
  spdlog::info(
    "Discovering camera using {} interface", FlirCamera::Impl::commInterfaceToString(communication_interface));

  spdlog::info("[discoverCamera] Allocating discovery context...");
  // Start scanning for nearby cameras
  struct FlirCamera::Impl::DiscoveryContext context = { false, ACS_Future_alloc() };
  check_acs(true);

  ACS_Discovery *discovery = ACS_Discovery_alloc();
  check_acs(true);
  spdlog::info("[discoverCamera] Discovery context allocated!");

  spdlog::info("[discoverCamera] Starting discovery scan...");
  ACS_Discovery_scan(discovery,
    communication_interface,
    FlirCamera::Impl::onCameraFound,
    FlirCamera::Impl::onDiscoveryError,
    FlirCamera::Impl::onCameraLost,
    FlirCamera::Impl::onDiscoveryFinished,
    &context);
  check_acs();
  spdlog::info("[discoverCamera] Discovery scan finished!");

  spdlog::info("[discoverCamera] Blocking until camera is discovered...");
  ACS_Identity *identity = reinterpret_cast<ACS_Identity *>(ACS_Future_get(context.futureIdentity));
  check_acs();
  spdlog::info("[discoverCamera] Camera discovered: {}", ACS_Identity_getDeviceId(identity));

  ACS_Future_free(context.futureIdentity);
  ACS_Discovery_free(discovery);
  spdlog::info("Freeing discovery context");

  return identity;
}

ACS_ThermalImage *FlirCamera::FlirCameraImpl::takeSnapshot() const
{
  const char *importFilePath = "./latest_snapshot.jpg";
  const bool doOverwrite = true;
  ACS_Importer *importer = ACS_Camera_getImporter(m_camera);
  ACS_StoredImage *storedImage = ACS_Remote_Storage_snapshot_executeSync(m_remote_control);
  if (ACS_getErrorCondition(ACS_getLastError()) == ACS_ERR_MISSING_STORAGE) {
    spdlog::error("[takeSnapshot] Camera storage error");
    return nullptr;
  }

  const ACS_FileReference *thermalImageRef = ACS_StoredImage_getThermalImage(storedImage);
  ACS_Future *fileImportFuture = ACS_Future_alloc();
  check_acs();
  ACS_Importer_importFileAs(importer,
    thermalImageRef,
    importFilePath,
    doOverwrite,
    FlirCamera::Impl::onImportComplete,
    FlirCamera::Impl::onImportError,
    FlirCamera::Impl::onImportProgress,
    fileImportFuture);
  check_acs();
  ACS_Future_get(fileImportFuture);
  check_acs();
  ACS_Future_free(fileImportFuture);
  ACS_StoredImage_free(storedImage);
  return FlirCamera::Impl::openThermalImage(importFilePath);
}

ACS_ThermalImage *FlirCamera::FlirCameraImpl::takeTemporarySnapshot() const
{
  ACS_Property_Int_setSync(ACS_Remote_Storage_fileFormat(m_remote_control), ACS_Storage_FileFormat_jpeg);
  check_acs();
  ACS_StoredLocalImage *localImage =
    ACS_Remote_Storage_snapshotToLocalFile_executeSync(m_remote_control, "./latest_snapshot.jpg", nullptr);
  check_acs();
  ACS_ThermalImage *thermalImage = FlirCamera::Impl::openThermalImage(ACS_StoredLocalImage_getThermalImage(localImage));
  spdlog::info("Imported snapshot as {}", ACS_StoredLocalImage_getThermalImage(localImage));
  ACS_StoredLocalImage_free(localImage);
  return thermalImage;
}

ACS_ThermalImage *FlirCamera::FlirCameraImpl::openThermalImage(const char *path)
{
  ACS_ThermalImage *thermalImage = ACS_ThermalImage_alloc();
  check_acs();
  ACS_NativeString *fileName = ACS_NativeString_createFrom(path);
  ACS_ThermalImage_openFromFile(thermalImage, ACS_NativeString_get(fileName));
  ACS_NativeString_free(fileName);
  check_acs();
  return thermalImage;
}

//============================================================================
// Static callback implementations.
//============================================================================

void FlirCamera::FlirCameraImpl::onCameraFound(const ACS_DiscoveredCamera *discoveredCamera, void *void_context)
{
  auto *context = static_cast<FlirCamera::Impl::DiscoveryContext *>(void_context);
  const ACS_Identity *identity = ACS_DiscoveredCamera_getIdentity(discoveredCamera);
  if (context->futureAlreadySet) {
    printf("(ignored) Camera \"%s\" found", ACS_DiscoveredCamera_getDisplayName(discoveredCamera));
    if (ACS_Identity_getIpAddress(identity)) {
      printf(" at: %s\n", ACS_Identity_getIpAddress(identity));
    } else {
      printf("\n");
    }
    return;
  }

  printf("Camera \"%s\" found", ACS_DiscoveredCamera_getDisplayName(discoveredCamera));
  if (ACS_Identity_getIpAddress(identity)) {
    printf(" at: %s\n", ACS_Identity_getIpAddress(identity));
  } else {
    printf("\n");
  }
  context->futureAlreadySet = true;
  ACS_Future_setValue(context->futureIdentity, ACS_Identity_copy(identity));
}

void FlirCamera::FlirCameraImpl::onDiscoveryError(ACS_CommunicationInterface cif, ACS_Error error, void *void_context)
{
  auto *context = static_cast<DiscoveryContext *>(void_context);
  printf("Discovery error on interface %u\n", cif);
  context->futureAlreadySet = true;
  ACS_Future_setError(context->futureIdentity, error);
}
void FlirCamera::FlirCameraImpl::onCameraLost(const ACS_Identity *identity, void * /*void_context*/)
{
  printf("Camera lost: %s\n", ACS_Identity_getDeviceId(identity));
}

void FlirCamera::FlirCameraImpl::onDiscoveryFinished(ACS_CommunicationInterface /*interface*/, void * /*void_context*/)
{
  printf("Discovery finished\n");
}

void FlirCamera::FlirCameraImpl::onDisconnect(ACS_Error error, void * /*context*/)
{
  printf("Lost connection to camera\n");
  checkACSError(error);
}

void FlirCamera::FlirCameraImpl::onImportComplete(void *context)
{
  if (context != nullptr) { ACS_Future_setValue(static_cast<ACS_Future *>(context), nullptr); }
}

void FlirCamera::FlirCameraImpl::onImportError(ACS_Error error, void *context)
{
  if (context != nullptr) { ACS_Future_setError(static_cast<ACS_Future *>(context), error); }
}

void FlirCamera::FlirCameraImpl::onImportProgress(const ACS_FileReference *file,
  long long current,
  long long total,
  void * /*context*/)
{
  if (file == nullptr) {
    printf("[onImportProgress] File is null\n");
    return;
  }

  printf("Importing file %s, %lld of %lld bytes\n", ACS_FileReference_getPath(file), current, total);
}

void FlirCamera::FlirCameraImpl::printStreamInformation(ACS_Camera *camera)
{
  size_t streamCount = ACS_Camera_getStreamCount(camera);
  if (streamCount == 0) {
    spdlog::error("No streams available");
    return;
  }
  for (size_t i = 0; i < streamCount; i++) {
    printf("Stream id:%zd, ", i);
    ACS_Stream *stream = ACS_Camera_getStream(camera, i);
    if (ACS_Stream_isThermal(stream)) {
      printf("Thermal Stream\n");
    } else {
      printf("Colorized Stream\n");
    }
  }
}

cv::Mat FlirCamera::FlirCameraImpl::convertACSBufferToCVMat(const ACS_ImageBuffer *imageBuffer,
  std::optional<StreamParameters> &stream_params)
{
  const unsigned char *pixel_data = ACS_ImageBuffer_getData(imageBuffer);

  // --- Parameter Retrieval (remains the same) ---
  if (stream_params == std::nullopt) {
    stream_params = StreamParameters{};
    stream_params->width = ACS_ImageBuffer_getWidth(imageBuffer);
    stream_params->height = ACS_ImageBuffer_getHeight(imageBuffer);
    stream_params->stride = ACS_ImageBuffer_getStride(imageBuffer);
    stream_params->bytes_per_pixel = ACS_ImageBuffer_getBytesPerPixel(imageBuffer);
    stream_params->color_space = ACS_ImageBuffer_getColorSpace(imageBuffer);

    spdlog::info(
      "Stream parameters: width={}, height={}, stride={}, bytes_per_pixel={}, "
      "color_space={}",
      stream_params->width,
      stream_params->height,
      stream_params->stride,
      stream_params->bytes_per_pixel,
      stream_params->color_space);
  }

  // --- Optimized Conversion Logic ---

  // Pre-calculate dimensions and scaling factor
  const int height = stream_params->height;
  const int width = stream_params->width;
  const int src_stride = stream_params->stride;
  static constexpr double scale_factor_8_to_16 = 65535.0 / 255.0;// 257.0

  // Create the final destination Mat directly
  cv::Mat img(height, width, CV_16UC1);

  // Choose processing path based on input format
  if (stream_params->color_space == ACS_ColorSpaceType_rgb && stream_params->bytes_per_pixel == 3) {
    cv::parallel_for_(cv::Range(0, height), [&](const cv::Range &range) {
      // Standard weights for RGB to Gray conversion (ITU-R BT.601)
      // Pre-calculate fixed-point weights for potential speedup if needed,
      // but floating point is usually fine and clearer.
      const float wr = 0.299f;
      const float wg = 0.587f;
      const float wb = 0.114f;

      for (int y = range.start; y < range.end; ++y) {
        const uchar *src_row = pixel_data + y * src_stride;
        ushort *dst_row = img.ptr<ushort>(y);

        for (int x = 0; x < width; ++x) {
          // Read RGB (assuming RGB order in source buffer)
          uchar r = src_row[x * 3 + 0];
          uchar g = src_row[x * 3 + 1];
          uchar b = src_row[x * 3 + 2];

          // Calculate 8-bit gray value
          uchar gray8 = static_cast<uchar>(wr * r + wg * g + wb * b);

          // Scale to 16-bit and store
          dst_row[x] = static_cast<ushort>(gray8 * scale_factor_8_to_16);
        }
      }
    });

  } else if (stream_params->color_space == ACS_ColorSpaceType_gray && stream_params->bytes_per_pixel == 2) {

    const int expected_stride = width * 2;// Expected stride for contiguous CV_16UC1

    // Check if source and destination strides allow a single memcpy
    if (src_stride == expected_stride && img.isContinuous()) {
      memcpy(img.ptr(), pixel_data, height * expected_stride);
    } else {
      // Fallback to parallel row-by-row copy if strides don't match
      cv::parallel_for_(cv::Range(0, height), [&](const cv::Range &range) {
        for (int y = range.start; y < range.end; ++y) {
          memcpy(img.ptr(y), pixel_data + y * src_stride, expected_stride);
        }
      });
    }

  } else if (stream_params->color_space == ACS_ColorSpaceType_gray && stream_params->bytes_per_pixel == 1) {
    cv::parallel_for_(cv::Range(0, height), [&](const cv::Range &range) {
      for (int y = range.start; y < range.end; ++y) {
        const uchar *src_row = pixel_data + y * src_stride;
        ushort *dst_row = img.ptr<ushort>(y);

        for (int x = 0; x < width; ++x) {
          // Read Gray8
          uchar gray8 = src_row[x];
          // Scale to 16-bit and store
          dst_row[x] = static_cast<ushort>(gray8 * scale_factor_8_to_16);
        }
      }
    });

  } else {
    // --- Unsupported Format --- (remains the same)
    std::string error_msg = "Unsupported format: color_space=" + std::to_string(stream_params->color_space)
                            + ", bytes_per_pixel=" + std::to_string(stream_params->bytes_per_pixel);
    spdlog::error(error_msg.c_str());
    throw std::runtime_error(error_msg);
  }

  // --- Final Check (remains the same) ---
  if (img.empty() || img.type() != CV_16UC1) {
    spdlog::error("Post-conversion check failed: Mat is empty or not CV_16UC1...");
    // Decide how to handle: return empty Mat, throw, etc.
    // return cv::Mat{};
  }

  return img;
}

//============================================================================
// End of FlirCamera Implementation
//============================================================================
