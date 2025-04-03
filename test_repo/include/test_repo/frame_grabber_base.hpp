#ifndef FRAME_GRABBER_BASE_HPP
#define FRAME_GRABBER_BASE_HPP

#include "camera_type.hpp"
#include <fstream>
#include <iostream>
#include <memory>
#include <opencv2/opencv.hpp>
#include <optional>
#include <string>
#include <test_repo/export_macros.hpp>
#include <vector>

namespace netxten::utils {

/**
 * @class FrameGrabberBase
 * @brief Abstract base class for frame grabbers that read frames from a file.
 *
 * This class provides the basic functionality for opening a file, reading frames,
 * and retrieving frame information. It is intended to be subclassed by specific
 * frame grabber implementations.
 */
class SAMPLE_LIBRARY_API FrameGrabberBase
{
protected:
  std::string m_file_path; /**< Path to the file from which frames are read. */
  std::unique_ptr<std::ifstream> m_file; /**< Unique pointer to the file stream */

  /**
   * @brief Pure virtual function to set up necessary data structures or indices.
   *
   * This method should be implemented by subclasses to handle specific setup logic
   * after the file is successfully opened.
   */
  virtual void setup() = 0;

public:
  /**
   * @brief Constructor to initialize the frame grabber with a file path.
   * @param path The path to the file to be read.
   */
  explicit FrameGrabberBase(std::string path);

  /**
   * @brief Virtual destructor to ensure proper cleanup.
   */
  virtual ~FrameGrabberBase();

  /**
   * @brief Deleted copy constructor to prevent copying.
   */
  FrameGrabberBase(const FrameGrabberBase &) = delete;

  /**
   * @brief Deleted copy assignment operator to prevent copying.
   */
  FrameGrabberBase &operator=(const FrameGrabberBase &) = delete;

  /**
   * @brief Move constructor.
   * @param other The object to move from.
   */
  FrameGrabberBase(FrameGrabberBase &&other) noexcept;

  /**
   * @brief Move assignment operator.
   * @param other The object to move from.
   * @return Reference to the assigned object.
   */
  FrameGrabberBase &operator=(FrameGrabberBase &&other) noexcept;

  /**
   * @brief Initializes the file and sets up necessary data structures.
   */
  void initialize();

  /**
   * @brief Returns the frame size as a pair of integers (height, width).
   * @return A pair representing the frame's height and width.
   */
  [[nodiscard]] virtual std::pair<int, int> getFrameSize() const = 0;

  /**
   * @brief Returns the total number of frames in the file.
   * @return The total number of frames.
   */
  [[nodiscard]] virtual size_t getNumberOfFrames() const = 0;

  /**
   * @brief Retrieves a specific frame by index.
   * @param index The index of the frame to retrieve.
   * @return A vector of characters representing the frame data.
   */
  [[nodiscard]] virtual std::vector<uint16_t> getFrame(size_t index) const = 0;

  /**
   * @brief Retrieves a specific frame by index as a cv::Mat.
   *
   * @param index The index of the frame to retrieve.
   * @return cv::Mat The frame as a cv::Mat.
   */
  [[nodiscard]] virtual cv::Mat getCvFrame(size_t index) const = 0;

  /**
   * @brief Get the frame rate of the video.
   *
   * @return double frame rate of the video.
   */
  [[nodiscard]] virtual double getFrameRate() const;

  /**
   * @brief Set the frame rate of the video.
   *
   * @param frame_rate The frame rate of the video.
   */
  void setFrameRate(double frame_rate);

  /**
   * @brief Get the camera model.
   *
   * @return std::string The camera model.
   */
  [[nodiscard]] virtual std::string getCameraModel() const;

  /**
   * @brief Set the camera model.
   *
   * @param camera_model The camera model.
   */
  void setCameraModel(std::string camera_model);

  /**
   * @brief Get the camera type based on the camera model.
   *
   * @return CameraType
   */
  [[nodiscard]] virtual netxten::types::CameraType getCameraType() const;

  /**
   * @brief Set the camera type.
   *
   * @param camera_type The camera type.
   */
  void setCameraType(netxten::types::CameraType camera_type);

  /**
   * @brief Closes the file if it is open.
   */
  void close();

  /**
   * @brief Check if the frame grabber is initialized. Throw if not.
   *
   */
  void checkInitialization() const;

private:
  std::optional<double> m_frame_rate_opt = std::nullopt;//*< Optional frame rate */
  std::optional<std::string> m_camera_model_opt = std::nullopt;//*< Optional camera model */
  std::optional<netxten::types::CameraType> m_camera_type_opt = std::nullopt;//*< Optional camera type */
  bool m_is_initialized = false; /**< Flag if frame grabber is initialized */
};

}// namespace netxten::utils


#endif /* FRAME_GRABBER_BASE_HPP */
