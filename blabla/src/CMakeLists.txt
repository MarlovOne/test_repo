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

# Helper function to discover and copy libraries
function(discover_and_copy_libraries target_name source_dir destination_dir
         extension)
  file(GLOB library_files "${source_dir}/*.${extension}")
  foreach(library_file ${library_files})
    add_custom_command(
      TARGET ${target_name}
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different ${library_file}
              ${destination_dir}
      COMMENT "Copying ${library_file}")
  endforeach()
endfunction()

# Install sample_library next to blabla
if(WIN32)
  # Add compile definition for spdlog
  target_compile_options(blabla PRIVATE /utf-8)
  target_link_directories(blabla PRIVATE "${test_repo_root_DIR}/bin"
                          "${test_repo_root_DIR}/lib")

  # Copy sample_library
  add_custom_command(
    TARGET blabla
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:test_repo::sample_library> $<TARGET_FILE_DIR:blabla>)

  # Discover and copy all DLLs and LIBs dynamically
  discover_and_copy_libraries(blabla "${test_repo_root_DIR}/bin"
                              "$<TARGET_FILE_DIR:blabla>" "dll")
  discover_and_copy_libraries(blabla "${test_repo_root_DIR}/lib"
                              "$<TARGET_FILE_DIR:blabla>" "lib")

endif()

if(ANDROID)
  # Support Android 15 16k page size
  target_link_options(blabla PRIVATE "-Wl,-z,max-page-size=16384")

  set(CUSTOM_INSTALL_LIBS
      "${test_repo_root_DIR}/lib/libavcodec.so"
      "${test_repo_root_DIR}/lib/libavdevice.so"
      "${test_repo_root_DIR}/lib/libavfilter.so"
      "${test_repo_root_DIR}/lib/libavformat.so"
      "${test_repo_root_DIR}/lib/libavutil.so"
      "${test_repo_root_DIR}/lib/libpostproc.so"
      "${test_repo_root_DIR}/lib/libswscale.so"
      "${test_repo_root_DIR}/lib/libswresample.so"
      "${test_repo_root_DIR}/lib/libc++_shared.so")
  foreach(lib ${CUSTOM_INSTALL_LIBS})
    add_custom_command(
      TARGET blabla
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different ${lib}
              $<TARGET_FILE_DIR:blabla>)
  endforeach()
endif()
