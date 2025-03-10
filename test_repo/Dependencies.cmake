include(cmake/CPM.cmake)

# Done as a function so that updates to variables like
# CMAKE_CXX_FLAGS don't propagate out to other
# targets
macro(test_repo_setup_dependencies)

  netxten_isolate_dependencies()
  add_liquid_dsp_dependency_isolated()
  add_ffmpeg_dependency_isolated()

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

  find_package(
    OpenCV REQUIRED
    COMPONENTS core
               imgproc
               features2d
               flann
               calib3d
               videoio
               video
               highgui)

endmacro()

macro(add_ffmpeg_dependency_isolated)

  set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")
  add_library(ffmpeg_interface INTERFACE)
  if(WIN32)
    cpmaddpackage(
      NAME
      ffmpeg-libs
      GIT_TAG
      windows
      GITHUB_REPOSITORY
      MarlovOne/ffmpeg-libs
      DOWNLOAD_ONLY
      TRUE)

    # Define the path to the ABI-specific directory from the repository.
    set(FFMPEG_PATH "${ffmpeg-libs_SOURCE_DIR}/${CMAKE_VS_PLATFORM_NAME}")
    message(STATUS "FFmpeg Windows path: ${FFMPEG_PATH}")

    # Set the include and library directories.
    set(FFMPEG_INCLUDE_DIRS "${FFMPEG_PATH}/include")
    set(FFMPEG_LIBRARY_DIRS "${FFMPEG_PATH}/lib")

    # Create an INTERFACE target for include directories (if desired).
    target_include_directories(ffmpeg_interface INTERFACE ${FFMPEG_INCLUDE_DIRS})

    # Create imported targets for each FFmpeg DLL and its import library.
    add_library(avcodec SHARED IMPORTED)
    set_property(TARGET avcodec PROPERTY IMPORTED_LOCATION "${FFMPEG_PATH}/bin/avcodec-61.dll")
    set_property(TARGET avcodec PROPERTY IMPORTED_IMPLIB "${FFMPEG_LIBRARY_DIRS}/avcodec.lib")

    add_library(avformat SHARED IMPORTED)
    set_property(TARGET avformat PROPERTY IMPORTED_LOCATION "${FFMPEG_PATH}/bin/avformat-61.dll")
    set_property(TARGET avformat PROPERTY IMPORTED_IMPLIB "${FFMPEG_LIBRARY_DIRS}/avformat.lib")

    add_library(avdevice SHARED IMPORTED)
    set_property(TARGET avdevice PROPERTY IMPORTED_LOCATION "${FFMPEG_PATH}/bin/avdevice-61.dll")
    set_property(TARGET avdevice PROPERTY IMPORTED_IMPLIB "${FFMPEG_LIBRARY_DIRS}/avdevice.lib")

    add_library(avfilter SHARED IMPORTED)
    set_property(TARGET avfilter PROPERTY IMPORTED_LOCATION "${FFMPEG_PATH}/bin/avfilter-10.dll")
    set_property(TARGET avfilter PROPERTY IMPORTED_IMPLIB "${FFMPEG_LIBRARY_DIRS}/avfilter.lib")

    add_library(avutil SHARED IMPORTED)
    set_property(TARGET avutil PROPERTY IMPORTED_LOCATION "${FFMPEG_PATH}/bin/avutil-59.dll")
    set_property(TARGET avutil PROPERTY IMPORTED_IMPLIB "${FFMPEG_LIBRARY_DIRS}/avutil.lib")

    add_library(postproc SHARED IMPORTED)
    set_property(TARGET postproc PROPERTY IMPORTED_LOCATION "${FFMPEG_PATH}/bin/postproc-58.dll")
    set_property(TARGET postproc PROPERTY IMPORTED_IMPLIB "${FFMPEG_LIBRARY_DIRS}/postproc.lib")

    add_library(swresample SHARED IMPORTED)
    set_property(TARGET swresample PROPERTY IMPORTED_LOCATION "${FFMPEG_PATH}/bin/swresample-5.dll")
    set_property(TARGET swresample PROPERTY IMPORTED_IMPLIB "${FFMPEG_LIBRARY_DIRS}/swresample.lib")

    add_library(swscale SHARED IMPORTED)
    set_property(TARGET swscale PROPERTY IMPORTED_LOCATION "${FFMPEG_PATH}/bin/swscale-8.dll")
    set_property(TARGET swscale PROPERTY IMPORTED_IMPLIB "${FFMPEG_LIBRARY_DIRS}/swscale.lib")

    target_link_libraries(
      ffmpeg_interface
      INTERFACE avcodec
                avformat
                avdevice
                avfilter
                avutil
                postproc
                swresample
                swscale)

  elseif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS" OR IOS)
    # URL for the FFmpeg iOS archive
    set(FFMPEG_IOS_URL "https://sourceforge.net/projects/ffmpeg-ios/files/latest/download")

    # Define paths for the downloaded archive and extraction directory.
    set(FFMPEG_IOS_ARCHIVE "${CMAKE_BINARY_DIR}/ffmpeg-ios-master.tar.bz2")
    set(FFMPEG_IOS_EXTRACT_DIR "${CMAKE_BINARY_DIR}/ffmpeg-ios")

    message(STATUS "Downloading FFmpeg iOS from ${FFMPEG_IOS_URL}")
    file(DOWNLOAD ${FFMPEG_IOS_URL} ${FFMPEG_IOS_ARCHIVE} SHOW_PROGRESS)

    message(STATUS "Extracting FFmpeg iOS to ${FFMPEG_IOS_EXTRACT_DIR}")
    file(MAKE_DIRECTORY ${FFMPEG_IOS_EXTRACT_DIR})
    file(
      ARCHIVE_EXTRACT
      INPUT
      ${FFMPEG_IOS_ARCHIVE}
      DESTINATION
      ${FFMPEG_IOS_EXTRACT_DIR})

    set(FFMPEG_INCLUDE_DIRS "${FFMPEG_IOS_EXTRACT_DIR}/FFmpeg-iOS/include")
    set(FFMPEG_LIBRARY_DIRS "${FFMPEG_IOS_EXTRACT_DIR}/FFmpeg-iOS/lib")

    # Tell CMake where to find the FFmpeg iOS headers and libraries.
    include_directories(${FFMPEG_INCLUDE_DIRS})
    link_directories(${FFMPEG_LIBRARY_DIRS})

    # Define a variable with the names of the libraries you wish to link.
    # Adjust these names if the libraries have prefixes (like "lib") or extensions.
    set(FFMPEG_LIBRARIES
        avcodec
        avformat
        avutil
        swscale
        swresample
        avfilter)
  elseif(ANDROID)

    cpmaddpackage(
      NAME
      ffmpeg-libs
      GIT_TAG
      android
      GITHUB_REPOSITORY
      MarlovOne/ffmpeg-libs
      DOWNLOAD_ONLY
      TRUE)

    # Define the path to the ABI-specific directory from the repository.
    set(FFMPEG_ANDROID_PATH "${ffmpeg-libs_SOURCE_DIR}/${ANDROID_ABI}")
    message(STATUS "FFmpeg Android path: ${FFMPEG_ANDROID_PATH}")
    # Set the include and library directories.
    set(FFMPEG_INCLUDE_DIRS "${FFMPEG_ANDROID_PATH}/include")
    set(FFMPEG_LIBRARY_DIRS "${FFMPEG_ANDROID_PATH}/lib")

    # Add the include directory so that FFmpeg headers are available.
    target_include_directories(ffmpeg_interface INTERFACE ${FFMPEG_INCLUDE_DIRS})
    target_link_libraries(
      ffmpeg_interface
      INTERFACE "${FFMPEG_LIBRARY_DIRS}/libavcodec.so"
                "${FFMPEG_LIBRARY_DIRS}/libavformat.so"
                "${FFMPEG_LIBRARY_DIRS}/libavutil.so"
                "${FFMPEG_LIBRARY_DIRS}/libswscale.so"
                "${FFMPEG_LIBRARY_DIRS}/libswresample.so"
                "${FFMPEG_LIBRARY_DIRS}/libavfilter.so")
  else()
    find_package(FFmpeg REQUIRED MODULE)
  endif()

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

  if(NOT TARGET nlohman_json)
    cpmaddpackage(
      NAME
      json
      GIT_TAG
      v3.11.3
      GITHUB_REPOSITORY
      nlohmann/json)
  endif()

  if(NOT TARGET charls)
    cpmaddpackage(
      NAME
      charls
      GIT_TAG
      2.4.2
      GITHUB_REPOSITORY
      team-charls/charls
      OPTIONS
      "BUILD_SHARED_LIBS OFF"
      "CMAKE_POSITION_INDEPENDENT_CODE ON"
      "CHARLS_INSTALL OFF")
  endif()
  set_target_properties(charls PROPERTIES PUBLIC_HEADER "")

  if(NOT TARGET pugixml)
    cpmaddpackage(
      NAME
      pugixml
      GIT_TAG
      v1.15
      GITHUB_REPOSITORY
      zeux/pugixml
      OPTIONS
      "BUILD_SHARED_LIBS OFF"
      "PUGIXML_BUILD_TESTS OFF"
      "PUGIXML_INSTALL OFF")
  endif()

endfunction()

function(add_liquid_dsp_dependency_isolated)
  if(NOT TARGET liquid)
    set(DOWNLOAD_ONLY "FALSE")
    if(WIN32)
      set(DOWNLOAD_ONLY "TRUE")
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
      DOWNLOAD_ONLY
      ${DOWNLOAD_ONLY})

    add_library(liquid_interface INTERFACE)
    add_library(liquid::liquid ALIAS liquid_interface)

    # Add liquid-dsp dependencies for Windows - use the precompiled library
    if(WIN32)
      # Add interface library which collects liquid-dsp dependencies
      if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x64")
        message(WARNING "64 bit architecture detected")
        set(ARCHITECTURE_NUMBER 64)
      else()
        set(ARCHITECTURE_NUMBER 32)
      endif()

      target_include_directories(liquid_interface INTERFACE ${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/lib/include)
      target_link_libraries(
        liquid_interface INTERFACE ${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/lib/msvc/${ARCHITECTURE_NUMBER}/libliquid.lib)
    else()
      # Add liquid-dsp dependencies for other platforms
      target_include_directories(
        liquid_interface INTERFACE $<BUILD_INTERFACE:${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/include>
                                   $<INSTALL_INTERFACE:include>)
      target_link_libraries(liquid_interface INTERFACE liquid)
    endif()
  endif()
endfunction()
