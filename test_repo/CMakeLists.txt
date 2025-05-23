cmake_minimum_required(VERSION 3.21)

# This template attempts to be "fetch_content"-able
# so that it works well with tools like CPM or other
# manual dependency management

# Only set the cxx_standard if it is not set by someone else
if(NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Because we're building with static library OpenCV - Runtimes need to be the same
if(WIN32)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT")
  set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /MT")
endif()

# strongly encouraged to enable this globally to avoid conflicts between
# -Wpedantic being enabled and -std=c++20 and -std=gnu++20 for example
# when compiling with PCH enabled
set(CMAKE_CXX_EXTENSIONS OFF)

# Set the project name and language
project(
  test_repo
  VERSION 0.0.1
  DESCRIPTION ""
  HOMEPAGE_URL "https://github.com/JaneaSystems/test_repo-aquantavision"
  LANGUAGES CXX C)

include(ProjectOptions.cmake)
test_repo_setup_options()
test_repo_global_options()
test_repo_local_options()
test_repo_architecture_options()

include(Dependencies.cmake)
test_repo_setup_dependencies()

set(GIT_SHA
    "Unknown"
    CACHE STRING "SHA this build was generated from")
string(
  SUBSTRING "${GIT_SHA}"
            0
            8
            GIT_SHORT_SHA)

target_compile_features(test_repo_options INTERFACE cxx_std_${CMAKE_CXX_STANDARD})

add_library(test_repo::test_repo_options ALIAS test_repo_options)
add_library(test_repo::test_repo_warnings ALIAS test_repo_warnings)

# configure files based on CMake configuration options
add_subdirectory(configured_files)

# Adding the src:
add_subdirectory(src)

# Don't even look at tests if we're not top level
if(NOT PROJECT_IS_TOP_LEVEL)
  return()
endif()

# Adding the tests:
include(CTest)

# If building on the android add -llog to the linker flags
if(ANDROID_NDK_TOOLCHAIN_INCLUDED)
  message(WARNING "Adding -llog to the linker flags for Android")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -llog")
endif()

# Do not build tests if cross compiling - unable to run them
if(BUILD_TESTING AND NOT CMAKE_CROSSCOMPILING)
  message(AUTHOR_WARNING "Building Tests. Be sure to check out test/constexpr_tests.cpp for constexpr testing")
  add_subdirectory(test)
endif()

# If MSVC is being used, and ASAN is enabled, we need to set the debugger environment
# so that it behaves well with MSVC's debugger, and we can run the target from visual studio
if(MSVC)
  get_all_installable_targets(all_targets)
  message("all_targets=${all_targets}")
  set_target_properties(${all_targets} PROPERTIES VS_DEBUGGER_ENVIRONMENT "PATH=$(VC_ExecutablePath_x64);%PATH%")
endif()

# set the startup project for the "play" button in MSVC
set_property(DIRECTORY PROPERTY VS_STARTUP_PROJECT sample_executable)

if(CMAKE_SKIP_INSTALL_RULES)
  return()
endif()

include(cmake/PackageProject.cmake)

# When on macos/ios install additional targets because of framework
set(ADDITIONAL_TARGETS "")
if(${CMAKE_SYSTEM_NAME} STREQUAL "iOS"
   OR IOS
   OR ${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
  list(
    APPEND
    ADDITIONAL_TARGETS
    liquid_interface
    liquid
    nlohmann_json
    eigen
    charls
    pugixml
    pugixml-static
    ffmpeg_interface
    flir_sdk)

  if(${SLA_SDK_FOUND})
    list(APPEND ADDITIONAL_TARGETS sla_sdk)
  endif()
endif()

# When on windows install additional targets because of ffmpeg
if(WIN32)
  list(
    APPEND
    ADDITIONAL_TARGETS
    ffmpeg_interface
    flir_sdk)
endif()

# Add other targets that you want installed here
test_repo_package_project(
  TARGETS
  sample_library
  sample_executable
  test_repo_options
  test_repo_warnings
  ${ADDITIONAL_TARGETS}
  PUBLIC_INCLUDES
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${OpenCV_INCLUDE_DIRS}"
  "${Eigen3_SOURCE_DIR}/Eigen")

# Detect architecture
if(CMAKE_SYSTEM_PROCESSOR)
  set(PKG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
else()
  set(PKG_ARCH "unknown")
endif()

# Check if building for Android
if(ANDROID_ABI)
  set(PKG_ARCH "${ANDROID_ABI}")

  # Check if building for macOS (Universal Binary)
elseif(CMAKE_OSX_ARCHITECTURES)
  set(PKG_ARCH "x86_64-arm64")

  # Check if building for Windows ARM64
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
    set(PKG_ARCH "arm64")
  else()
    set(PKG_ARCH "x86_64") # Default to x86_64 if not explicitly ARM64
  endif()
endif()

# Experience shows that explicit package naming can help make it easier to sort
# out potential ABI related issues before they start, while helping you
# track a build to a specific GIT SHA
set(CPACK_PACKAGE_FILE_NAME
    "${CMAKE_PROJECT_NAME}-${CMAKE_PROJECT_VERSION}-${GIT_SHORT_SHA}-${CMAKE_SYSTEM_NAME}-${CMAKE_BUILD_TYPE}-${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}-${PKG_ARCH}"
)

include(CPack)
