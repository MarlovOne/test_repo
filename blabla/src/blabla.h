#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#if __cplusplus
    #define FFI_PLUGIN_EXPORT extern "C" __declspec(dllexport)
#else
    #define FFI_PLUGIN_EXPORT __declspec(dllexport)
#endif
#else
#if __cplusplus
#define FFI_PLUGIN_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#else
#define FFI_PLUGIN_EXPORT
#endif
#endif

FFI_PLUGIN_EXPORT int sum(int a, int b);
FFI_PLUGIN_EXPORT int factorial(int input);
FFI_PLUGIN_EXPORT const char* getVersion();
FFI_PLUGIN_EXPORT void process_image(uint8_t *input_data, const int width, const int height, const int channels, uint8_t *output_data);