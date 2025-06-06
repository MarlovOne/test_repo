#include <catch2/catch_test_macros.hpp>


#include <opencv2/opencv.hpp>
#include <test_repo/sample_library.hpp>


TEST_CASE("Factorials are computed", "[factorial]")
{
  cv::VideoCapture cap(0);
  REQUIRE(test_repo::factorial(0) == 1);
  REQUIRE(test_repo::factorial(1) == 1);
  REQUIRE(test_repo::factorial(2) == 2);
  REQUIRE(test_repo::factorial(3) == 6);
  REQUIRE(test_repo::factorial(10) == 3628800);
}
