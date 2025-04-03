#include <spdlog/spdlog.h>
#include <test_repo/constants.hpp>
#include <test_repo/ts_grabber.hpp>

using namespace netxten::utils;


TSGrabber::TSGrabber(const std::string &file_path, bool convert_to_16_bit)
  : FrameGrabberBase(file_path), m_convert_to_16bit(convert_to_16_bit)
{
  spdlog::info("TSGrabber::TSGrabber({})", file_path);
}

size_t TSGrabber::getNumberOfFrames() const
{
  checkInitialization();
  return m_total_frames;
}

cv::Mat TSGrabber::getCvFrame(size_t index) const
{
  checkInitialization();

  // Retrieve raw frame data (BGR24) from the extractor.
  auto frame_opt = m_extractor->getFrame(index);
  if (!frame_opt.has_value() || frame_opt->empty()) {
    spdlog::warn("[TSGrabber] Failed to read frame at index {}", index);
    return cv::Mat{};
  }

  // Create a cv::Mat from the raw data.
  cv::Mat bgr_image(
    static_cast<int>(m_frame_size.height), static_cast<int>(m_frame_size.width), CV_8UC3, frame_opt->data());

  // Convert to grayscale if necessary.
  cv::Mat gray_image;
  if (bgr_image.channels() == 3) {
    cv::cvtColor(bgr_image, gray_image, cv::COLOR_BGR2GRAY);
  } else {
    gray_image = std::move(bgr_image);
  }

  cv::Mat image_16;
  if (m_convert_to_16bit) {
    // Multiply 8-bit grayscale image by 257 to scale to 16-bit.
    gray_image.convertTo(image_16, CV_16U, SCALE_FACTOR);
  } else {
    gray_image.convertTo(image_16, CV_16U);
  }

  return image_16;
}

std::vector<uint16_t> TSGrabber::getFrame(size_t index) const
{
  checkInitialization();

  // Retrieve the converted 16-bit frame.
  cv::Mat image_16 = getCvFrame(index);
  if (image_16.empty()) {
    spdlog::warn("getFrame: empty frame at index {}", index);
    return {};
  }

  // Assume the image data is continuous. Copy the data to a vector.
  // TODO: Check if the image data is continuous.
  size_t total_pixels = image_16.total();
  const uint16_t *dataPtr = image_16.ptr<uint16_t>(0);
  return std::vector<uint16_t>(dataPtr, dataPtr + total_pixels);
}

std::pair<int, int> TSGrabber::getFrameSize() const
{
  checkInitialization();
  return { m_frame_size.height, m_frame_size.width };
}

void TSGrabber::setup()
{
  try {
    // Initialize TSFrameExtractor using the file path from the base class.
    m_extractor = std::make_unique<TSFrameExtractor>(m_file_path);
    auto _ = m_extractor->getFrame(0);

    // Check frame_size
    auto frame_size_opt = m_extractor->getFrameSize();
    if (!frame_size_opt.has_value()) {
      spdlog::error("Failed to get frame size from TS file: {}", m_file_path);
      throw std::runtime_error("Failed to get frame size from TS file: " + m_file_path);
    }

    m_frame_size = frame_size_opt.value();
    m_total_frames = m_extractor->getTotalFrames();
    m_frame_rate = m_extractor->getFrameRate();
    spdlog::info("TSGrabber::setup: frame size: {}x{}, total frames: {}, frame rate: {}",
      m_frame_size.width,
      m_frame_size.height,
      m_total_frames,
      m_frame_rate);

  } catch (const std::exception &e) {
    spdlog::error("Failed to initialize TS file: {}. Error: {}", m_file_path, e.what());
    throw std::runtime_error("Failed to initialize TS file: " + m_file_path + ". Error: " + e.what());
  }
}

double TSGrabber::getFrameRate() const
{
  checkInitialization();
  return m_frame_rate;
}