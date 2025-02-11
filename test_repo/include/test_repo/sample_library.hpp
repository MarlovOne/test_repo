#ifndef SAMPLE_LIBRARY_HPP
#define SAMPLE_LIBRARY_HPP

#include <string>

namespace test_repo {

int add(int a, int b);

std::string getProjectVersion();

[[nodiscard]] int factorial(int) noexcept;

[[nodiscard]] constexpr int factorial_constexpr(int input) noexcept
{
  if (input == 0) { return 1; }

  return input * factorial_constexpr(input - 1);
}

void process_image(uint8_t *input_data, const int width, const int height, const int channels, uint8_t *output_data);

}// namespace test_repo

#endif