#ifndef SAMPLE_LIBRARY_HPP
#define SAMPLE_LIBRARY_HPP

#include <cstdint>
#include <string>
#include <test_repo/export_macros.hpp>

namespace test_repo {

SAMPLE_LIBRARY_API int add(int a, int b);

SAMPLE_LIBRARY_API std::string getProjectVersion();

[[nodiscard]] SAMPLE_LIBRARY_API int factorial(int) noexcept;

[[nodiscard]] SAMPLE_LIBRARY_API constexpr int factorial_constexpr(int input) noexcept
{
  if (input == 0) { return 1; }

  return input * factorial_constexpr(input - 1);
}

SAMPLE_LIBRARY_API void process_image(uint8_t *input_data, const int width, const int height, const int channels, uint8_t *output_data);

}// namespace test_repo

#endif