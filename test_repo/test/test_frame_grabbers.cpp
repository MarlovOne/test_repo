#include <catch2/catch_test_macros.hpp>
#include <spdlog/spdlog.h>
#include <stdexcept>
#include <string>
#include <vector>

#include <test_repo/ts_grabber.hpp>

// File paths for testing
static const auto FILE_PATH_TS = "resources/Viento_LWIR-OGI-Test12-Run56-Methane-1kghr.ts";
static constexpr auto TS_HEIGHT = 480;
static constexpr auto TS_WIDTH = 640;

using namespace netxten::utils;

/**
 * @brief Generic test for grabbers implementing FrameGrabberBase.
 *
 * @tparam T The grabber class.
 * @param file_path The file path to the grabber data.
 * @param expected_height The expected frame height.
 * @param expected_width The expected frame width.
 */
template<typename T> void test_grabber_basics(const std::string &file_path, int expected_height, int expected_width)
{
  // Construct a grabber instance.
  T grabber(file_path);
  grabber.initialize();

  // Test frame size.
  auto frame_size = grabber.getFrameSize();
  int height = frame_size.first;
  int width = frame_size.second;
  REQUIRE(height == expected_height);
  REQUIRE(width == expected_width);

  // Test number of frames.
  size_t num_frames = grabber.getNumberOfFrames();
  REQUIRE(num_frames > 0);

  // Test first frame.
  std::vector<uint16_t> first_frame = grabber.getFrame(0);
  REQUIRE_FALSE(first_frame.empty());
  // Since the image is 2D, we expect a total number of pixels equal to height * width.
  REQUIRE(first_frame.size() == static_cast<size_t>(expected_height * expected_width));

  // Test last frame.
  std::vector<uint16_t> last_frame = grabber.getFrame(num_frames - 1);
  REQUIRE_FALSE(last_frame.empty());
  REQUIRE(last_frame.size() == static_cast<size_t>(expected_height * expected_width));

  // If there's more than one frame, test a middle frame.
  if (num_frames > 1) {
    std::vector<uint16_t> mid_frame = grabber.getFrame(num_frames / 2);
    REQUIRE_FALSE(mid_frame.empty());
    REQUIRE(mid_frame.size() == static_cast<size_t>(expected_height * expected_width));
  }

  // Test out-of-range index (should throw an exception).
  REQUIRE_THROWS_AS(grabber.getFrame(num_frames), std::out_of_range);

  // Close the grabber.
  grabber.close();
}

template<typename T> void test_uninitialized_grabber()
{
  T grabber("invalid_file_path");
  REQUIRE_THROWS_AS(grabber.getFrameSize(), std::runtime_error);
  REQUIRE_THROWS_AS(grabber.getNumberOfFrames(), std::runtime_error);
  REQUIRE_THROWS_AS(grabber.getFrame(0), std::runtime_error);
  grabber.close();
}

TEST_CASE("TSGrabber Basic Tests", "[grabber]")
{
  // Run basic tests for SEQGrabber.
  spdlog::info("Running basic tests for TSGrabber");
  test_grabber_basics<netxten::utils::TSGrabber>(FILE_PATH_TS, TS_HEIGHT, TS_WIDTH);
}

TEST_CASE("TSGrabber Uninitialized Tests", "[grabber]")
{
  // Run basic tests for SEQGrabber.
  spdlog::info("Running uninitialized tests for TSGrabber");
  test_uninitialized_grabber<netxten::utils::TSGrabber>();
}