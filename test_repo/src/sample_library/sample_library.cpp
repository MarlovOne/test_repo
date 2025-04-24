#include <charls/charls.h>
#include <iostream>
#include <liquid/liquid.h>
#include <nlohmann/json.hpp>
#include <opencv2/opencv.hpp>
#include <pugixml.hpp>
#include <spdlog/spdlog.h>
#include <test_repo/flir_camera.hpp>
#include <test_repo/sample_library.hpp>
#include <fineftp/server.h>

#ifndef FLIR_SDK_FOUND
#define FLIR_SDK_FOUND 1
#endif

extern "C" {
#if FLIR_SDK_FOUND && !FLIR_SDK_IOS_FOUND
#include <acs/acs.h>
#include <acs/camera.h>
#include <acs/discovery.h>
#include <acs/renderer.h>
#include <acs/thermal_image.h>
#include <acs/utility.h>
#endif
#include <libavcodec/avcodec.h>
}

#include <SLAHalOs.h>

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
std::string test_repo::getProjectVersion()
{
  // Print the FFmpeg libavcodec version
  unsigned version = avcodec_version();
  std::cout << "FFmpeg avcodec version: " << version << std::endl;
  return "0.0.1";
}

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

void test_repo::test()
{
  cv::VideoCapture cap(0);
  pugi::xml_document doc;
#if FLIR_SDK_FOUND && !FLIR_SDK_IOS_FOUND
  ACS_Discovery *discovery = ACS_Discovery_alloc();
#endif
  SLATrace("Hello world!");

#if FLIR_SDK_FOUND
  netxten::camera::FlirCamera flir_camera;
  bool ret = flir_camera.connect({});
  flir_camera.startStream();
  auto [frame_number, frame] = flir_camera.getLatestFrame(0);
#endif
  fineftp::FtpServer ftp_server(2121);
}
