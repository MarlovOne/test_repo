#include <opencv2/opencv.hpp>
#include <spdlog/spdlog.h>
#include <test_repo/sample_library.hpp>
#include <liquid/liquid.h>

int test_repo::factorial(int input) noexcept
{
  int result = 1;
  spdlog::info("Calculating factorial of {}", input);

  while (input > 0) {
    result *= input;
    --input;
  }

  return result;
}

int test_repo::add(int a, int b) { return a + b; }
std::string test_repo::getProjectVersion() { return "0.0.1"; }

void test_repo::process_image(uint8_t *input_data,
  const int width,
  const int height,
  const int channels,
  uint8_t *output_data)
{
  if (!input_data || width <= 0 || height <= 0 || channels != 3) { return; }

  // Convert raw data to OpenCV Mat
  cv::Mat input_mat(height, width, CV_8UC3, reinterpret_cast<void *>(input_data));
  cv::Mat output_mat(height, width, CV_8UC3, reinterpret_cast<void *>(output_data));

  // Copy input to output
  input_mat.copyTo(output_mat);
}