#ifndef NEXTEN_CAMERA_FLIR_CAMERA_HPP
#define NEXTEN_CAMERA_FLIR_CAMERA_HPP

#include "frame.hpp"
#include <functional>
#include <memory>
#include <opencv2/opencv.hpp>
#include <optional>
#include <string>
#include <test_repo/export_macros.hpp>

namespace netxten::camera {
/**
 * @brief Encapsulates FLIR camera discovery, connection, configuration, and image capture
 * functionality.
 */
class SAMPLE_LIBRARY_API FlirCamera
{
public:
  using Ptr = std::unique_ptr<FlirCamera>;

  /**
   * @brief Constructs a new FlirCamera instance.
   */
  FlirCamera();

  /**
   * @brief Destructs the FlirCamera instance, ensuring proper resource release.
   */
  ~FlirCamera();

  // Delete copy and assignment operators.
  FlirCamera(const FlirCamera &) = delete;
  FlirCamera &operator=(const FlirCamera &) = delete;

  // Delete move constructor and move assignment operator.
  FlirCamera(FlirCamera &&other) = delete;
  FlirCamera &operator=(FlirCamera &&other) = delete;

  /**
   * @brief Parameters used for connecting to a FLIR camera.
   */
  struct ConnectionParameters
  {
    std::string ip = "";///< Camera IP address (empty string triggers discovery).
    int communication_interface = 8;///< Communication interface identifier (e.g.,
                                    ///< ACS_CommunicationInterface_emulator).
    bool colorized_streaming = false;///< Enables colorized thermal streaming if true.

    // Authentication parameters
    bool authenticate_with_camera = false;///< Enables authentication with camera.
    std::string certificate_path = "./";///< Path to the certificate file.
    std::string certificate_name = "sample-app-cert";///< Name of the certificate.
    std::string common_name = "network_sample_app";///< Common name for the certificate.
  };

  /**
   * @brief Parameters describing the stream image format.
   */
  struct StreamParameters
  {
    int width = 640;///< Width of the streamed image in pixels.
    int height = 480;///< Height of the streamed image in pixels.
    int stride = 0;///< Number of bytes between the start of consecutive image rows.
    int bytes_per_pixel = 2;///< Number of bytes per pixel.
    int color_space = 0;///< Color space identifier (e.g., RGB, grayscale).
    double frame_rate = 30.0;///< Frame rate of the streamed image in frames per second.
  };

  enum CommunicationInterface {
    usb = 0x01,///< USB port. T1K, EXX, T6XX, T4XX
    network = 0x2,///< Network adapter. A300, A310, AX8
    emulator = 0x8,///< Emulating device interface
  };

  /**
   * @brief Connect to a FLIR camera.
   *
   * @param params Connection parameters. If IP is empty, camera discovery will be
   * initiated.
   * @return True if connection was successful, false otherwise.
   */
  [[nodiscard]] bool connect(const ConnectionParameters &params);

  /**
   * @brief Disconnect from the FLIR camera and release resources.
   */
  void disconnect();

  /**
   * @brief Trigger autofocus on the connected camera.
   */
  void autofocus();

  /**
   * @brief Capture a thermal image snapshot.
   *
   * @return A pointer to the captured snapshot data. Caller must call freeSnapshot() to
   * release resources.
   */
  [[nodiscard]] void *captureSnapshot();

  /**
   * @brief Frees resources associated with a snapshot.
   *
   * @param snapshot Pointer to the snapshot data to free.
   */
  static void freeSnapshot(void *snapshot);

  /**
   * @brief Print basic camera information retrieved from a snapshot.
   */
  void printCameraInfo();

  /**
   * @brief Start the camera streaming process.
   */
  void startStream();

  /**
   * @brief Stop the camera streaming process.
   */
  void stopStream();

  /**
   * @brief Display camera stream using FLIR SDK's native visualization. Used for
   * demonstration purposes only.
   */
  void playStream();

  /**
   * @brief Display camera stream using OpenCV visualization. Used for demonstration
   * purposes only.
   */
  void playStreamCV();

  /**
   * @brief Retrieve the latest camera frame since the last retrieved frame.
   *
    @param lastSeenFrame The frame identifier last seen by the caller.
   * @return A pair containing the new frame identifier and the corresponding OpenCV image
   * if a newer frame is available; otherwise, an empty optional.
   */
  std::pair<uint64_t, std::optional<cv::Mat>> getLatestFrame(uint64_t lastSeenFrame);

  /**
   * @brief Retrieves the camera model name.
   *
   * Queries the connected camera for its model name.
   *
   * @return An optional string containing the camera model name, or an empty optional if
   * unavailable.
   */
  [[nodiscard]] std::optional<std::string> getModelName() const;

  /**
   * @brief Retrieves the camera's frame rate.
   *
   * Returns the frame rate of the camera stream if available.
   *
   * @return An optional double representing the frame rate in frames per second, or an
   * empty optional if unavailable.
   */
  [[nodiscard]] std::optional<double> getFrameRate() const;

  /**
   * @brief Retrieves the size of the camera frame.
   *
   * Returns the dimensions (width and height) of the current camera frame.
   *
   * @return An optional FrameSize structure containing the frame width and height, or an
   * empty optional if unavailable.
   */
  [[nodiscard]] std::optional<netxten::types::FrameSize> getFrameSize() const;

  /**
   * @brief Checks whether the camera is currently connected.
   *
   * @return true if the camera is connected; false otherwise.
   */
  [[nodiscard]] bool isConnected() const;

  /**
   * @brief Checks whether the camera streaming process is active.
   *
   * @return true if streaming is active; false otherwise.
   */
  [[nodiscard]] bool isStreaming() const;

protected:
  class FlirCameraImpl;
  using Impl = FlirCameraImpl;

  std::unique_ptr<FlirCameraImpl> m_impl;///< Implementation pointer for internal camera management.

private:
  /**
   * @brief Check the status of the last executed ACS SDK operation.
   *
   * @param throw_on_error If true, throw an exception upon detecting an error.
   */
  static void check_acs(bool throw_on_error = false);

  ConnectionParameters m_conn_params = {};///< Current connection parameters.
  std::optional<StreamParameters> m_stream_params = std::nullopt;///< Optional stream configuration parameters.
  unsigned long m_callbacks_received = 0;///< Counter for received streaming callbacks (frames).
  bool m_streaming = false;///< Indicates whether streaming is active.
  std::optional<cv::Mat> m_previous_frame = std::nullopt;///< Stores the previous frame for comparison.
};
}// namespace netxten::camera

#endif /* NEXTEN_CAMERA_FLIR_CAMERA_HPP */
