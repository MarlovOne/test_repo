#include <filesystem>
#include <map>
#include <optional>
#include <spdlog/spdlog.h>
#include <test_repo/frame.hpp>
#include <test_repo/ts_frame_extractor.hpp>

// FFmpeg headers
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

using namespace netxten::utils;
using namespace netxten::types;

/**
 * @brief Internal implementation for TSFrameExtractor.
 *
 * This class encapsulates the FFmpeg-based logic for decoding video frames,
 * retrieving video metadata (total frames, frame rate, duration), and managing
 * keyframe indices. It is not exposed directly to users; see TSFrameExtractor.
 */
class TSFrameExtractor::TSFrameExtractorImpl
{
public:
  TSFrameExtractorImpl(const TSFrameExtractorImpl &) = delete;
  TSFrameExtractorImpl &operator=(const TSFrameExtractorImpl &) = delete;
  TSFrameExtractorImpl(TSFrameExtractorImpl &&) = delete;
  TSFrameExtractorImpl &operator=(TSFrameExtractorImpl &&) = delete;

  /**
   * @brief Constructs the TSFrameExtractorImpl with a given video filename.
   *
   * Opens the video file, initializes the FFmpeg context, builds the keyframe index.
   *
   * @param filename The path to the video file.
   */
  explicit TSFrameExtractorImpl(const std::string &filename);

  /**
   * @brief Destructor that cleans up all allocated FFmpeg resources.
   */
  ~TSFrameExtractorImpl();

  /**
   * @brief Retrieves a specific frame by frame number.
   *
   * Returns the frame data in BGR24 format as a vector of bytes.
   *
   * @param frame_number The zero-based index of the frame to retrieve.
   * @return std::optional containing the frame data if successful, std::nullopt
   * otherwise.
   */
  std::optional<std::vector<uint8_t>> getFrame(size_t frame_number);

  /**
   * @brief Gets the total number of frames in the video.
   *
   * @return Total frame count, or 0 if not available.
   */
  size_t getTotalFrames() const;

  /**
   * @brief Retrieves the video frame rate.
   *
   * @return Frame rate as a double.
   */
  double getFrameRate() const;

  /**
   * @brief Retrieves the video duration in seconds.
   *
   * @return Video duration (seconds).
   */
  double getDuration() const;

  /**
   * @brief Retrieves a sorted list of keyframe positions.
   *
   * @return A vector containing keyframe indices in ascending order.
   */
  std::vector<int> getKeyframePositions() const;

  /**
   * @brief Get the Frame Size object
   *
   * @return std::optional<FrameSize>
   */
  std::optional<FrameSize> getFrameSize() const;

private:
  int m_current_frame_index = -1;//*< Current frame index (for sequential decoding).
  bool m_sequential_active = false;//*< Flag indicating if sequential decoding is active.
  std::string m_filename;//*< Video filename.
  AVFormatContext *m_container = nullptr;//*< FFmpeg format context.
  AVStream *m_stream = nullptr;//*< Pointer to the video stream.
  AVCodecContext *m_decoder_context = nullptr;//*< Cached decoder context.
  std::optional<int> m_frame_count = std::nullopt;//*< Total frame count.
  std::optional<FrameSize> m_frame_size = std::nullopt;//*< Frame size (width, height).
  std::map<size_t, TSFrameInfo> m_keyframe_positions;//*< Mapping of keyframe indices to frame info.
  std::unordered_map<int64_t, int> m_frame_indices;//*< Mapping of packet pts to frame indices.

  /**
   * @brief Builds the keyframe index from the video container.
   *
   * Iterates through the packets in the video, identifying keyframes based on a minimum
   * interval, and calculates the total number of frames.
   */
  void build_keyframe_index();

  /**
   * @brief Seeks to the nearest previous keyframe for the given frame number.
   *
   * @param frame_number The target frame number.
   * @return Optional keyframe index if found; std::nullopt otherwise.
   */
  std::optional<size_t> seek_to_keyframe(size_t frame_number);

  /**
   * @brief Decodes frames until a specified condition is met.
   *
   * This helper function reads packets from the container and decodes frames,
   * incrementing the current frame index. When the provided condition (a predicate on the
   * frame index) returns true, the frame is converted to BGR24 and returned.
   *
   * @param current_frame_idx Reference to the current frame index.
   * @param condition A callable that takes an int (frame index) and returns true when the
   * target frame is reached.
   * @return An optional vector of bytes containing the frame data in BGR24 format.
   */
  std::optional<std::vector<uint8_t>> decode_frames_until_condition(size_t current_frame_idx,
    const std::function<bool(size_t)> &condition);

  /**
   * @brief Decodes frames from a starting index until the target frame index is reached.
   *
   * @param start_idx The frame index from which decoding should start.
   * @param target_idx The target frame index to decode until.
   * @return An optional vector of bytes containing the target frame data.
   */
  std::optional<std::vector<uint8_t>> decode_frames_until(size_t start_idx, size_t target_idx);

  /**
   * @brief Decodes the next available frame in sequential mode.
   *
   * Reads packets without seeking and decodes the first frame available. The frame is
   * converted to BGR24.
   *
   * @return An optional vector of bytes containing the frame data.
   */
  std::optional<std::vector<uint8_t>> decode_next_sequential_frame();

  /**
   * @brief Set the sequence active object.
   *
   * @param active
   */
  void set_sequence_active(bool active);
};

TSFrameExtractor::TSFrameExtractorImpl::TSFrameExtractorImpl(const std::string &filename) : m_filename(filename)
{
  spdlog::info("Creating TSFrameExtractorImpl");

  // Check if the file exists using C++17 filesystem.
  if (!std::filesystem::exists(filename)) { throw std::runtime_error("Video file not found: " + filename); }

  // Open the input file/container.
  int ret = avformat_open_input(&m_container, filename.c_str(), nullptr, nullptr);
  if (ret < 0) {
    std::array<char, AV_ERROR_MAX_STRING_SIZE> errbuf = {};
    av_strerror(ret, errbuf.data(), errbuf.size());
    spdlog::error("Failed to open video file: {}", errbuf.data());
    throw std::runtime_error(std::string("Failed to open video file: ") + errbuf.data());
  }

  // Retrieve stream information.
  ret = avformat_find_stream_info(m_container, nullptr);
  if (ret < 0) {
    std::array<char, AV_ERROR_MAX_STRING_SIZE> errbuf = {};
    av_strerror(ret, errbuf.data(), errbuf.size());
    spdlog::error("Failed to find stream info: {}", errbuf.data());
    throw std::runtime_error(std::string("Failed to find stream info: ") + errbuf.data());
  }

  // Locate the first video stream.
  for (unsigned int i = 0; i < m_container->nb_streams; ++i) {
    if (m_container->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
      m_stream = m_container->streams[i];
      break;
    }
  }
  if (m_stream == nullptr) {
    spdlog::error("No video streams found in file");
    throw std::runtime_error("No video streams found in file");
  }

  // Build the initial keyframe index.
  build_keyframe_index();
}

TSFrameExtractor::TSFrameExtractorImpl::~TSFrameExtractorImpl()
{
  spdlog::info("Destroying TSFrameExtractorImpl");
  if (m_container != nullptr) { avformat_close_input(&m_container); }
  if (m_decoder_context != nullptr) { avcodec_free_context(&m_decoder_context); }
}

std::optional<size_t> TSFrameExtractor::TSFrameExtractorImpl::seek_to_keyframe(size_t frame_number)
{
  // Find the maximum key in m_keyframe_positions that is <= frame_number.
  auto keyframe_it = m_keyframe_positions.upper_bound(frame_number);
  if (keyframe_it == m_keyframe_positions.begin()) {
    spdlog::warn("No suitable keyframe found for frame {}", frame_number);
    return std::nullopt;
  }
  --keyframe_it;// Now it points to the greatest key that is <= frame_number.
  size_t keyframe_idx = keyframe_it->first;

  // Get keyframe info using the found key.
  const TSFrameInfo &keyframe_info = m_keyframe_positions.at(keyframe_idx);

  // Try to seek to the keyframe, retrying as needed.
  for (int attempt = 0; attempt < TSFrameExtractor::SEEK_RETRY_COUNT; ++attempt) {
    int ret = av_seek_frame(m_container, m_stream->index, keyframe_info.pts, AVSEEK_FLAG_BACKWARD);
    if (ret >= 0) {
      spdlog::info("Seek successful to keyframe at frame {}", keyframe_idx);
      return std::make_optional(keyframe_idx);// Successful seek.
    }
    std::array<char, AV_ERROR_MAX_STRING_SIZE> errbuf{};
    av_strerror(ret, errbuf.data(), errbuf.size());
    spdlog::warn("Seek attempt {} failed: {}", attempt + 1, errbuf.data());
    if (attempt == TSFrameExtractor::SEEK_RETRY_COUNT - 1) {
      spdlog::error("Seek attempt failed after maximum retries");
      throw std::runtime_error("Seek attempt failed after maximum retries");
    }
  }
  return std::nullopt;
}

void TSFrameExtractor::TSFrameExtractorImpl::build_keyframe_index()
{
  spdlog::info("Building keyframe index");

  // Seek to the beginning of the file.
  if (av_seek_frame(m_container, m_stream->index, 0, AVSEEK_FLAG_BACKWARD) < 0) {
    spdlog::error("Error seeking to beginning of file");
    throw std::runtime_error("Error seeking to beginning of file");
  }

  int frame_idx = 0;
  // Use the MIN_KEYFRAME_INTERVAL constant from the outer TSFrameExtractor class.
  int last_keyframe_idx = -TSFrameExtractor::MIN_KEYFRAME_INTERVAL;

  AVPacket packet;
  av_init_packet(&packet);
  packet.data = nullptr;
  packet.size = 0;

  // Demux packets from the container.
  while (av_read_frame(m_container, &packet) >= 0) {
    if (packet.stream_index == m_stream->index) {
      // Check for keyframe using the FFmpeg flag and interval.
      if ((packet.flags & AV_PKT_FLAG_KEY)
          && (frame_idx - last_keyframe_idx >= TSFrameExtractor::MIN_KEYFRAME_INTERVAL)) {
        m_keyframe_positions.emplace(frame_idx, TSFrameInfo{ packet.pts, packet.dts, true, packet.pos });
        last_keyframe_idx = frame_idx;
      }
      // Map packet pts to frame index if pts is valid.
      if (packet.pts != AV_NOPTS_VALUE) {
        m_frame_indices[packet.pts] = frame_idx;
        ++frame_idx;
      }
    }
    av_packet_unref(&packet);
  }

  // Calculate total frame count based on stream duration and frame rate.
  double duration_seconds = m_stream->duration * av_q2d(m_stream->time_base);
  double base_rate = av_q2d(m_stream->r_frame_rate);
  m_frame_count = static_cast<int>(duration_seconds * base_rate);

  spdlog::info("Indexed {} keyframes in {} total frames", m_keyframe_positions.size(), m_frame_count.value());

  // Seek back to the beginning for sequential reading.
  if (av_seek_frame(m_container, m_stream->index, 0, AVSEEK_FLAG_BACKWARD) < 0) {
    spdlog::error("Error seeking back to beginning of file");
    throw std::runtime_error("Error seeking back to beginning of file");
  }
}

std::optional<std::vector<uint8_t>> TSFrameExtractor::TSFrameExtractorImpl::getFrame(size_t frame_number)
{
  // Check range.
  auto total_frames = getTotalFrames();
  if (frame_number < 0 || frame_number >= total_frames) {
    throw std::out_of_range("Frame number " + std::to_string(frame_number) + " out of range");
  }

  // --- Sequential Access ---
  if (frame_number == static_cast<size_t>(m_current_frame_index + 1) && m_sequential_active) {
    if (auto nextFrame = decode_next_sequential_frame(); nextFrame.has_value()) {
      m_current_frame_index = static_cast<int>(frame_number);
      return nextFrame;
    }
    // If decoding failed, disable sequential mode.
    set_sequence_active(false);
  }

  // Ensure m_decoder_context is valid.
  if (m_decoder_context == nullptr) {
    const AVCodec *codec = avcodec_find_decoder(m_stream->codecpar->codec_id);
    if (codec == nullptr) {
      spdlog::error("Decoder not found for codec id");
      throw std::runtime_error("Decoder not found for codec id");
    }

    m_decoder_context = avcodec_alloc_context3(codec);
    if (m_decoder_context == nullptr) {
      spdlog::error("Failed to allocate decoder context");
      throw std::runtime_error("Failed to allocate decoder context");
    }

    if (avcodec_parameters_to_context(m_decoder_context, m_stream->codecpar) < 0) {
      spdlog::error("Failed to copy codec parameters to decoder context");
      avcodec_free_context(&m_decoder_context);
      throw std::runtime_error("Failed to copy codec parameters to decoder context");
    }

    if (avcodec_open2(m_decoder_context, codec, nullptr) < 0) {
      spdlog::error("Failed to open decoder");
      avcodec_free_context(&m_decoder_context);
      throw std::runtime_error("Failed to open decoder");
    }
  }

  // --- Handle Frame 0 Specially ---
  if (frame_number == 0) {
    // Seek to beginning.
    if (av_seek_frame(m_container, m_stream->index, 0, AVSEEK_FLAG_BACKWARD) < 0) {
      spdlog::error("Error seeking to beginning of file");
      return std::nullopt;
    }

    // Flush the decoder buffers to ensure a clean start.
    avcodec_flush_buffers(m_decoder_context);
    set_sequence_active(true);
    m_current_frame_index = -1;
    if (auto firstFrame = decode_next_sequential_frame(); firstFrame.has_value()) {
      m_current_frame_index = 0;
      return firstFrame;
    } else {
      spdlog::error("Error accessing first frame");
      set_sequence_active(false);
      return std::nullopt;
    }
  }

  // --- Random Access ---
  try {
    // Seek to the nearest previous keyframe.
    if (auto keyframe_opt = seek_to_keyframe(frame_number); keyframe_opt.has_value()) {
      // Decode frames from that keyframe until the requested frame is reached.
      auto frame_data = decode_frames_until(keyframe_opt.value(), frame_number);
      // Random access resets sequential state.
      set_sequence_active(false);
      return frame_data;
    }
    return std::nullopt;
  } catch (const std::exception &e) {
    spdlog::error("Error during random access: {}", e.what());
    return std::nullopt;
  }
}

std::optional<std::vector<uint8_t>> TSFrameExtractor::TSFrameExtractorImpl::decode_frames_until_condition(
  size_t current_frame_idx,
  const std::function<bool(size_t)> &condition)
{
  // Allocate an AVPacket for reading compressed data.
  AVPacket *packet = av_packet_alloc();
  if (packet == nullptr) {
    spdlog::error("Failed to allocate packet");
    return std::nullopt;
  }

  // Allocate an AVFrame for decoding raw frames.
  AVFrame *frame = av_frame_alloc();
  if (frame == nullptr) {
    spdlog::error("Failed to allocate frame");
    av_packet_free(&packet);
    return std::nullopt;
  }

  bool target_frame_found = false;// Flag to indicate if target frame is reached.
  std::optional<std::vector<uint8_t>> result = std::nullopt;// Optional result for the frame data.

  // Loop over packets from the container.
  while (av_read_frame(m_container, packet) >= 0) {
    // Process only packets belonging to the video stream.
    if (packet->stream_index != m_stream->index) {
      av_packet_unref(packet);// Unreference packets not belonging to our stream.
      continue;
    }

    // Send the packet to the decoder.
    int ret = avcodec_send_packet(m_decoder_context, packet);
    if (ret < 0) {
      std::array<char, AV_ERROR_MAX_STRING_SIZE> errbuf{};
      av_strerror(ret, errbuf.data(), errbuf.size());
      spdlog::error("Error sending packet to decoder: {}", errbuf.data());
      break;
    }

    // Process all available decoded frames.
    while (true) {
      ret = avcodec_receive_frame(m_decoder_context, frame);
      if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
        spdlog::warn("[TSFrameExtractorImpl] Decoder returned EAGAIN or EOF");
        break;
      } else if (ret < 0) {
        std::array<char, AV_ERROR_MAX_STRING_SIZE> errbuf{};
        av_strerror(ret, errbuf.data(), errbuf.size());
        spdlog::error("Error receiving frame from decoder: {}", errbuf.data());
        break;
      }

      // Increment the frame counter for every successfully decoded frame.
      current_frame_idx++;

      // If the condition is not met for the current frame - continue.
      if (!condition(current_frame_idx)) { continue; }

      // Condition met: prepare to convert the frame.
      // Create a scaling context to convert the frame to BGR24.
      SwsContext *sws_ctx = sws_getContext(frame->width,
        frame->height,
        static_cast<AVPixelFormat>(frame->format),
        frame->width,
        frame->height,
        AV_PIX_FMT_BGR24,
        SWS_BILINEAR,
        nullptr,
        nullptr,
        nullptr);
      if (sws_ctx == nullptr) {
        spdlog::error("Failed to create sws context for conversion");
        break;
      }

      // Determine the required buffer size for the BGR24 converted image.
      int num_bytes = av_image_get_buffer_size(AV_PIX_FMT_BGR24, frame->width, frame->height, 1);
      std::vector<uint8_t> buffer(num_bytes);// Allocate the output buffer.

      // Setup destination pointers and linesizes for the conversion.
      uint8_t *dest_data[4] = { buffer.data(), nullptr, nullptr, nullptr };
      int dest_linesize[4] = { frame->width * 3, 0, 0, 0 };

      // Perform the conversion using sws_scale.
      int converted_height =
        sws_scale(sws_ctx, frame->data, frame->linesize, 0, frame->height, dest_data, dest_linesize);
      sws_freeContext(sws_ctx);// Free the scaling context.

      // Check if the full frame was converted.
      if (converted_height != frame->height) {
        spdlog::error(
          "Frame conversion incomplete: converted height {} != frame height {}", converted_height, frame->height);
        break;
      }

      // Save the converted buffer as the result.
      result = std::move(buffer);
      target_frame_found = true;

      // Set frame size
      if (!m_frame_size.has_value()) {
        spdlog::info("Setting frame size to {}x{}", frame->height, frame->width);
        m_frame_size = FrameSize{ static_cast<size_t>(frame->height), static_cast<size_t>(frame->width) };
      }

      break;// Exit the inner loop as the target frame has been found.
    }

    // Unreference the packet after processing.
    av_packet_unref(packet);

    // If target frame has been found, exit the loop.
    if (target_frame_found) {
      spdlog::info("Target frame {} found", current_frame_idx);
      break;
    }
  }

  // Free the allocated frame and packet.
  av_frame_free(&frame);
  av_packet_free(&packet);

  if (!target_frame_found) { spdlog::warn("Target frame condition was not met during decoding"); }
  return result;
}

// Random access: decode frames from a given start index until target_idx is reached.
std::optional<std::vector<uint8_t>> TSFrameExtractor::TSFrameExtractorImpl::decode_frames_until(size_t start_idx,
  size_t target_idx)
{
  int local_frame_idx = start_idx - 1;
  auto condition = [target_idx](int frame_idx) { return frame_idx == target_idx; };
  return decode_frames_until_condition(local_frame_idx, condition);
}

// Sequential access: decode the next available frame.
std::optional<std::vector<uint8_t>> TSFrameExtractor::TSFrameExtractorImpl::decode_next_sequential_frame()
{
  int local_frame_idx = m_current_frame_index;// m_currentFrameIdx is a member tracking
                                              // the last decoded frame.
  // For sequential access, we simply accept the first decoded frame.
  auto condition = [](int /*frame_idx*/) { return true; };
  auto result = decode_frames_until_condition(local_frame_idx, condition);
  // Update the persistent sequential frame index.
  if (result.has_value()) {
    spdlog::info("Decoded frame {}", local_frame_idx);
    m_current_frame_index = local_frame_idx;
  } else {
    spdlog::error("[decode_next_sequential_frame] Error decoding frame {}", local_frame_idx);
  }
  return result;
}

double TSFrameExtractor::TSFrameExtractorImpl::getFrameRate() const
{
  // Return the frame rate using the average frame rate from the stream.
  return av_q2d(m_stream->avg_frame_rate);
}

double TSFrameExtractor::TSFrameExtractorImpl::getDuration() const
{
  // Calculate duration in seconds.
  return m_stream->duration * av_q2d(m_stream->time_base);
}

std::vector<int> TSFrameExtractor::TSFrameExtractorImpl::getKeyframePositions() const
{
  // Extract keys from the keyframe map.
  std::vector<int> positions;
  for (const auto &kv : m_keyframe_positions) { positions.push_back(kv.first); }
  return positions;
}

void TSFrameExtractor::TSFrameExtractorImpl::set_sequence_active(bool active)
{
  spdlog::info("Setting sequence active to {}", active);
  m_sequential_active = active;
}

std::optional<FrameSize> TSFrameExtractor::TSFrameExtractorImpl::getFrameSize() const { return m_frame_size; }

size_t TSFrameExtractor::TSFrameExtractorImpl::getTotalFrames() const
{
  return m_frame_count.has_value() ? m_frame_count.value() : 0;
}

size_t TSFrameExtractor::getTotalFrames() const { return m_impl->getTotalFrames(); }

double TSFrameExtractor::getFrameRate() const { return m_impl->getFrameRate(); }

double TSFrameExtractor::getDuration() const { return m_impl->getDuration(); }

std::vector<int> TSFrameExtractor::getKeyframePositions() const { return m_impl->getKeyframePositions(); }

TSFrameExtractor::TSFrameExtractor(const std::string &filename)
{
  m_impl = std::make_unique<TSFrameExtractorImpl>(filename);
}

std::optional<std::vector<uint8_t>> TSFrameExtractor::getFrame(size_t frame_number)
{
  return m_impl->getFrame(frame_number);
}

std::optional<netxten::types::FrameSize> TSFrameExtractor::getFrameSize() const { return m_impl->getFrameSize(); }


TSFrameExtractor::~TSFrameExtractor() = default;