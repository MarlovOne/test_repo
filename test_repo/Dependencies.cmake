include(cmake/CPM.cmake)

# Done as a function so that updates to variables like
# CMAKE_CXX_FLAGS don't propagate out to other
# targets
macro(test_repo_setup_dependencies)
  # For each dependency, see if it's
  # already been provided to us by a parent project
  if(NOT TARGET Catch2::Catch2WithMain)
    cpmaddpackage("gh:catchorg/Catch2@3.3.2")
  endif()

  # TODO(lmark): This if a forked dependency, move it to Marcus after
  if(NOT CPPYSTRUCT_SOURCE_DIR)
    cpmaddpackage("gh:MarlovOne/cppystruct#master")
  endif()

  if(NOT EIGEN_FOUND)
    cpmaddpackage("gl:libeigen/eigen#3.4")
  endif()

  if(NOT TARGET spdlog::spdlog)
    cpmaddpackage(
      NAME
      spdlog
      GIT_TAG
      v1.15.1
      GITHUB_REPOSITORY
      gabime/spdlog
      OPTIONS
      "SPDLOG_BUILD_SHARED OFF"
      "BUILD_SHARED_LIBS OFF"
      "SPDLOG_BUILD_PIC ON")
  endif()

  # Include OpenCV
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    cpmaddpackage("gh:MarlovOne/opencv-staticlib#linux-4.11")
    set(OpenCV_DIR ${CPM_PACKAGE_opencv-staticlib_SOURCE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/lib/cmake/opencv4)
  elseif(ANDROID)
    # Run scripts/install_deps_android.sh to install OpenCV
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../install/Android/opencv/OpenCV-android-sdk/sdk/native/jni)
  elseif(WIN32)
    cpmaddpackage("gh:MarlovOne/opencv-staticlib#windows-4.11")
    set(OpenCV_DIR
        ${CPM_PACKAGE_opencv-staticlib_SOURCE_DIR}/${CMAKE_VS_PLATFORM_NAME}/${CMAKE_VS_PLATFORM_NAME}/vc17/staticlib)
  elseif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin" AND NOT IOS)
    cpmaddpackage("gh:MarlovOne/opencv-staticlib#macos-4.11")
    set(OpenCV_DIR ${CPM_PACKAGE_opencv-staticlib_SOURCE_DIR}/arm64-x64/lib/cmake/opencv4)
  elseif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS" OR IOS)
    cpmaddpackage("gh:MarlovOne/opencv-staticlib#ios-4.11")
    set(OpenCV_DIR ${CPM_PACKAGE_opencv-staticlib_SOURCE_DIR}/arm64/lib/cmake/opencv4)
  else()
    message(FATAL_ERROR "Unsupported platform")
  endif()

  find_package(OpenCV REQUIRED COMPONENTS core imgproc)

endmacro()
