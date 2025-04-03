#ifndef NETXTEN_UTILS_TS_GRABBER_HPP
#define NETXTEN_UTILS_TS_GRABBER_HPP

#include "frame.hpp"
#include "frame_grabber_base.hpp"
#include "ts_frame_extractor.hpp"
#include <test_repo/export_macros.hpp>

namespace netxten::utils {
class SAMPLE_LIBRARY_API TSGrabber : public FrameGrabberBase
{
public:
  TSGrabber(const std::string &file_path, bool convert_to_16bit = true);

  TSGrabber(const TSGrabber &) = delete;
  TSGrabber &operator=(const TSGrabber &) = delete;
  TSGrabber(TSGrabber &&) = delete;
  TSGrabber &operator=(TSGrabber &&) = delete;

  [[nodiscard]] size_t getNumberOfFrames() const override;
  [[nodiscard]] std::vector<uint16_t> getFrame(size_t index) const override;
  [[nodiscard]] std::pair<int, int> getFrameSize() const override;
  [[nodiscard]] cv::Mat getCvFrame(size_t index) const override;
  [[nodiscard]] double getFrameRate() const override;

protected:
  /**
   * @brief Initializes the video capture object and retrieves video properties.
   */
  void setup() override;

private:
  bool m_convert_to_16bit = true;//*< Flag to convert frames to 16-bit grayscale.
  std::unique_ptr<class TSFrameExtractor> m_extractor;//*< Pointer to the frame extractor.
  netxten::types::FrameSize m_frame_size;//*< Video frame size.
  size_t m_total_frames = 0;//*< Total number of frames.
  double m_frame_rate = -1;//*< Video frame rate.
};
}// namespace netxten::utils
#endif /* NETXTEN_UTILS_TS_GRABBER_HPP */