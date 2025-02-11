#include <iostream>
#include <test_repo/sample_library.hpp>

int main([[maybe_unused]] int argc, [[maybe_unused]] char **argv)
{
  std::cout << test_repo::factorial(5) << "\n";
  return 0;
}
