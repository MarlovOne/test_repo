#ifndef NETXTEN_UTILS_TS_FRAME_EXTRACTOR_HPP
#define NETXTEN_UTILS_TS_FRAME_EXTRACTOR_HPP

#include "frame.hpp"
#include <memory>
#include <optional>
#include <string>
#include <test_repo/export_macros.hpp>
#include <vector>

namespace netxten::utils {

/**
 * @brief A class for extracting frames from transport stream video files.
 *
 * TSFrameExtractor provides methods for sequential and random access to video frames,
 * as well as metadata queries such as total frames, frame rate, duration, and keyframe
 * positions.
 */
class SAMPLE_LIBRARY_API TSFrameExtractor
{
public:
  /**
   * @brief Constructs a TSFrameExtractor for the specified video file.
   *
   * @param filename The path to the video file.
   * @throws std::runtime_error if the file cannot be found or opened.
   */
  explicit TSFrameExtractor(const std::string &filename);

  /**
   * @brief Destructor that cleans up resources.
   */
  ~TSFrameExtractor();

  /**
   * @brief Retrieves a specific frame by its frame number.
   *
   * The frame is returned as a vector of bytes in BGR24 format.
   *
   * @param frame_number The zero-based index of the desired frame.
   * @return An optional vector containing the frame data if successful, or std::nullopt
   * on failure.
   * @throws std::invalid_argument if the frame number is out of range.
   */
  std::optional<std::vector<uint8_t>> getFrame(size_t frame_number);

  /**
   * @brief Gets the total number of frames in the video.
   *
   * @return The total frame count.
   */
  [[nodiscard]] size_t getTotalFrames() const;

  /**
   * @brief Gets the video frame rate.
   *
   * @return The frame rate as a double.
   */
  [[nodiscard]] double getFrameRate() const;

  /**
   * @brief Gets the video duration in seconds.
   *
   * @return The duration of the video in seconds.
   */
  [[nodiscard]] double getDuration() const;

  /**
   * @brief Gets a sorted list of keyframe positions.
   *
   * @return A vector containing the keyframe indices.
   */
  [[nodiscard]] std::vector<int> getKeyframePositions() const;

  /**
   * @brief Get the Frame Size object
   *
   * @return std::optional<netxten::types::FrameSize>
   */
  [[nodiscard]] std::optional<netxten::types::FrameSize> getFrameSize() const;

  // Delete copy and move operations.
  TSFrameExtractor(const TSFrameExtractor &) = delete;//*< Deleted copy constructor.
  TSFrameExtractor &operator=(const TSFrameExtractor &) = delete;//*< Deleted copy assignment operator.
  TSFrameExtractor(TSFrameExtractor &&) = delete;//*< Deleted move constructor.
  TSFrameExtractor &operator=(TSFrameExtractor &&) = delete;//*< Deleted move assignment operator.

private:
  static constexpr auto SEEK_RETRY_COUNT = 3;//*< Seek retry count.
  static constexpr auto MIN_KEYFRAME_INTERVAL = 30;//*< Minimum keyframe interval.
  static constexpr auto DEFAULT_TIMEOUT = 5.0;//*< Default timeout in seconds.

  /**
   * @brief Private implementation class for TSFrameExtractor.
   */
  class TSFrameExtractorImpl;

  /**
   * @brief Pointer to the implementation (PIMPL idiom).
   */
  std::unique_ptr<TSFrameExtractorImpl> m_impl;//*< Pointer to implementation details.
};

}// namespace netxten::utils
#endif /* NETXTEN_UTILS_TS_FRAME_EXTRACTOR_HPP */