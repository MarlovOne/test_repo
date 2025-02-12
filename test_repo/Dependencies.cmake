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

  # Include OpenCV
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../install/Linux/opencv/${CMAKE_SYSTEM_PROCESSOR}/lib/cmake/opencv4)
  elseif(ANDROID)
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../install/android/opencv/OpenCV-android-sdk/sdk/native/jni)
  elseif(WIN32)
    set(OpenCV_DIR
        ${CMAKE_SOURCE_DIR}/../install/Windows/opencv/${CMAKE_VS_PLATFORM_NAME}/${CMAKE_VS_PLATFORM_NAME}/vc17/staticlib
    )
  elseif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin" AND NOT IOS)
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../install/macos/opencv/lib/cmake/opencv4)
  elseif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS" OR IOS)
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../install/ios/opencv/lib/cmake/opencv4)
  else()
    message(FATAL_ERROR "Unsupported platform")
  endif()

  find_package(
    Eigen3
    3.4
    REQUIRED
    NO_MODULE)
  find_package(OpenCV REQUIRED COMPONENTS core imgproc)

endmacro()
