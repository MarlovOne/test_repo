# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause the
# plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(
  blabla_library
  VERSION 0.0.1
  LANGUAGES CXX C)

# Set location where test_repo is installed
if(ANDROID)
  set(test_repo_root_DIR
      "${CMAKE_CURRENT_SOURCE_DIR}/../android/lib/${ANDROID_ABI}")
elseif(LINUX)
  set(test_repo_root_DIR
      "${CMAKE_CURRENT_SOURCE_DIR}/../linux/arch/${CMAKE_SYSTEM_PROCESSOR}")
elseif(WIN32)
  # Figure out which architecture we're building for on Windows
  if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
    set(test_repo_ARCH "x64_arm64")
  else()
    set(test_repo_ARCH "x64")
  endif()

  set(test_repo_root_DIR
      "${CMAKE_CURRENT_SOURCE_DIR}/../windows/arch/${test_repo_ARCH}")
else()
  message(FATAL_ERROR "Unsupported platform")
endif()

set(test_repo_DIR "${test_repo_root_DIR}/share/test_repo")
find_package(test_repo CONFIG REQUIRED)
add_library(blabla SHARED "blabla.cpp")
target_link_libraries(blabla PRIVATE test_repo::sample_library)
set_target_properties(blabla PROPERTIES PUBLIC_HEADER blabla.hpp OUTPUT_NAME
                                                                 "blabla")
target_include_directories(blabla PRIVATE "${test_repo_root_DIR}/opencv4"
                                          "${test_repo_root_DIR}")
target_compile_definitions(blabla PUBLIC DART_SHARED_LIB)

# Install sample_library next to blabla
if(WIN32)
  target_link_directories(blabla PRIVATE "${test_repo_root_DIR}/bin"
                          "${test_repo_root_DIR}/lib")
  add_custom_command(
    TARGET blabla
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:test_repo::sample_library> $<TARGET_FILE_DIR:blabla>)
  add_custom_command(
    TARGET blabla
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${test_repo_root_DIR}/bin"
            $<TARGET_FILE_DIR:blabla>)

  # Define the FFmpeg dependency DLLs.
  set(FFMPEG_DLLS
      "${test_repo_root_DIR}/bin/avcodec-61.dll"
      "${test_repo_root_DIR}/bin/avformat-61.dll"
      "${test_repo_root_DIR}/bin/avdevice-61.dll"
      "${test_repo_root_DIR}/bin/avfilter-10.dll"
      "${test_repo_root_DIR}/bin/avutil-59.dll"
      "${test_repo_root_DIR}/bin/postproc-58.dll"
      "${test_repo_root_DIR}/bin/swresample-5.dll"
      "${test_repo_root_DIR}/bin/swscale-8.dll")

  # Define the FFmpeg dependency .lib files.
  set(FFMPEG_LIBS
      "${test_repo_root_DIR}/lib/avcodec.lib"
      "${test_repo_root_DIR}/lib/avformat.lib"
      "${test_repo_root_DIR}/lib/avdevice.lib"
      "${test_repo_root_DIR}/lib/avfilter.lib"
      "${test_repo_root_DIR}/lib/avutil.lib"
      "${test_repo_root_DIR}/lib/postproc.lib"
      "${test_repo_root_DIR}/lib/swresample.lib"
      "${test_repo_root_DIR}/lib/swscale.lib")

  # Copy FFmpeg DLLs.
  foreach(dll ${FFMPEG_DLLS})
    add_custom_command(
      TARGET blabla
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different ${dll}
              $<TARGET_FILE_DIR:blabla>)
  endforeach()

  # Copy FFmpeg .lib files.
  foreach(lib ${FFMPEG_LIBS})
    add_custom_command(
      TARGET blabla
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different ${lib}
              $<TARGET_FILE_DIR:blabla>)
  endforeach()
endif()

if(ANDROID)
  # Support Android 15 16k page size
  target_link_options(blabla PRIVATE "-Wl,-z,max-page-size=16384")
endif()
