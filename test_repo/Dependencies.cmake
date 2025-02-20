include(cmake/CPM.cmake)

# Done as a function so that updates to variables like
# CMAKE_CXX_FLAGS don't propagate out to other
# targets
macro(test_repo_setup_dependencies)

  netxten_isolate_dependencies()
  add_liquid_dsp_dependency_isolated()

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

function(netxten_isolate_dependencies)

  # For each dependency, see if it's
  # already been provided to us by a parent project
  if(NOT TARGET Catch2::Catch2WithMain)
    cpmaddpackage("gh:catchorg/Catch2@3.3.2")
  endif()

  # TODO(lmark): This if a forked dependency, move it to Marcus after, also opencv-staticlib
  if(NOT CPPYSTRUCT_SOURCE_DIR)
    cpmaddpackage("gh:MarlovOne/cppystruct#master")
  endif()

  if(NOT EIGEN_FOUND)
    cpmaddpackage("gl:libeigen/eigen#3.4")
  endif()

  if(NOT TARGET spdlog::spdlog)
    # Install on macos and iOS since we're building static libraries there
    set(SPDLOG_INSTALL OFF)
    if(${CMAKE_SYSTEM_NAME} STREQUAL "iOS"
       OR IOS
       OR ${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
      set(SPDLOG_INSTALL ON)
    endif()

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
      "SPDLOG_BUILD_PIC ON"
      "SPDLOG_ENABLE_PCH ON"
      "SPDLOG_INSTALL ${SPDLOG_INSTALL}")
  endif()

  if (NOT TARGET nlohman_json)
    cpmaddpackage("gh:nlohman/json@3.11.3")
  endif()

endfunction()

function(add_liquid_dsp_dependency_isolated)
  if(NOT TARGET liquid)
    set (DOWNLOAD_ONLY "FALSE")
    if (WIN32)
      set (DOWNLOAD_ONLY "TRUE")
    endif()
    cpmaddpackage(
      NAME
      liquid-dsp
      GIT_TAG
      v1.7.0
      GITHUB_REPOSITORY
      MarlovOne/liquid-dsp
      OPTIONS
      "BUILD_SHARED_LIBS OFF"
      "BUILD_EXAMPLES OFF"
      "BUILD_AUTOTESTS OFF"
      "ENABLE_SIMD OFF"
      "BUILD_BENCHMARKS OFF"
      DOWNLOAD_ONLY ${DOWNLOAD_ONLY})
      
      add_library(liquid_interface INTERFACE)
      add_library(liquid::liquid ALIAS liquid_interface)
 
      # Add liquid-dsp dependencies for Windows - use the precompiled library
      if (WIN32) 
        # Add interface library which collects liquid-dsp dependencies
        if (CMAKE_SYSTEM_PROCESSOR STREQUAL "x64")
          message(WARNING "64 bit architecture detected")
          set(ARCHITECTURE_NUMBER 64)
        else()
          set(ARCHITECTURE_NUMBER 32)
        endif()
        
        target_include_directories(liquid_interface INTERFACE ${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/lib/include)
        target_link_libraries(liquid_interface INTERFACE ${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/lib/msvc/${ARCHITECTURE_NUMBER}/libliquid.lib)
      else()
        # Add liquid-dsp dependencies for other platforms
        target_include_directories(liquid_interface INTERFACE $<BUILD_INTERFACE:${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/include> $<INSTALL_INTERFACE:include>)
        target_link_libraries(liquid_interface INTERFACE liquid)
      endif()
  endif()
endfunction()
