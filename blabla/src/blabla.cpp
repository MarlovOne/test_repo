#include "blabla.h"
#include <cstring>
#include <string>
#include <test_repo/sample_library.hpp>

FFI_PLUGIN_EXPORT int sum(int a, int b) { return test_repo::add(a, b); }
FFI_PLUGIN_EXPORT int factorial(int input) {
  return test_repo::factorial(input);
}
FFI_PLUGIN_EXPORT const char *getVersion() {
  return strdup(test_repo::getProjectVersion().c_str());
}
FFI_PLUGIN_EXPORT void process_image(uint8_t *input_data, const int width,
                                     const int height, const int channels,
                                     uint8_t *output_data) {
  test_repo::process_image(input_data, width, height, channels, output_data);
}