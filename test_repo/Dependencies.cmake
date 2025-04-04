include(cmake/CPM.cmake)

# Done as a function so that updates to variables like
# CMAKE_CXX_FLAGS don't propagate out to other
# targets
macro(test_repo_setup_dependencies)

  netxten_isolate_dependencies()
  add_liquid_dsp_dependency_isolated()
  add_ffmpeg_dependency_isolated()
  add_flir_sdk_dependency()

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

    cpmaddpackage(
      NAME
      ffmpeg-libs
      GIT_TAG
      ios
      GITHUB_REPOSITORY
      MarlovOne/ffmpeg-libs
      DOWNLOAD_ONLY
      TRUE)

    # Set include and library directories based on the downloaded repository.
    set(FFMPEG_INCLUDE_DIRS "${ffmpeg-libs_SOURCE_DIR}/FFmpeg-iOS/include")
    set(FFMPEG_LIBRARY_DIRS "${ffmpeg-libs_SOURCE_DIR}/FFmpeg-iOS/lib")

    # # Add the include directory so that FFmpeg headers are available.
    # target_include_directories(ffmpeg_interface INTERFACE ${FFMPEG_INCLUDE_DIRS})

    # Add static imported libraries.
    add_library(avcodec STATIC IMPORTED)
    set_property(TARGET avcodec PROPERTY IMPORTED_LOCATION "${FFMPEG_LIBRARY_DIRS}/libavcodec.a")

    add_library(avdevice STATIC IMPORTED)
    set_property(TARGET avdevice PROPERTY IMPORTED_LOCATION "${FFMPEG_LIBRARY_DIRS}/libavdevice.a")

    add_library(avfilter STATIC IMPORTED)
    set_property(TARGET avfilter PROPERTY IMPORTED_LOCATION "${FFMPEG_LIBRARY_DIRS}/libavfilter.a")

    add_library(avformat STATIC IMPORTED)
    set_property(TARGET avformat PROPERTY IMPORTED_LOCATION "${FFMPEG_LIBRARY_DIRS}/libavformat.a")

    add_library(avutil STATIC IMPORTED)
    set_property(TARGET avutil PROPERTY IMPORTED_LOCATION "${FFMPEG_LIBRARY_DIRS}/libavutil.a")

    add_library(swresample STATIC IMPORTED)
    set_property(TARGET swresample PROPERTY IMPORTED_LOCATION "${FFMPEG_LIBRARY_DIRS}/libswresample.a")

    add_library(swscale STATIC IMPORTED)
    set_property(TARGET swscale PROPERTY IMPORTED_LOCATION "${FFMPEG_LIBRARY_DIRS}/libswscale.a")

    # Link the imported libraries to the interface target.
    target_link_libraries(
      ffmpeg_interface
      INTERFACE avcodec
                avdevice
                avformat
                avutil
                swresample
                swscale
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

    # add the include directory so that ffmpeg headers are available.
    target_include_directories(ffmpeg_interface INTERFACE ${FFMPEG_INCLUDE_DIRS})
    target_link_libraries(
      ffmpeg_interface
      INTERFACE "${FFMPEG_LIBRARY_DIRS}/libavcodec.so"
                "${FFMPEG_LIBRARY_DIRS}/libavformat.so"
                "${FFMPEG_LIBRARY_DIRS}/libavutil.so"
                "${FFMPEG_LIBRARY_DIRS}/libswscale.so"
                "${FFMPEG_LIBRARY_DIRS}/libswresample.so"
                "${FFMPEG_LIBRARY_DIRS}/libavfilter.so")
  elseif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin" AND NOT IOS)

    cpmaddpackage(
      NAME
      ffmpeg-libs
      GIT_TAG
      macos
      GITHUB_REPOSITORY
      MarlovOne/ffmpeg-libs
      DOWNLOAD_ONLY
      TRUE)

    # Set the include and library directories.
    set(FFMPEG_PATH "${ffmpeg-libs_SOURCE_DIR}")
    set(FFMPEG_INCLUDE_DIRS "${FFMPEG_PATH}/include")
    set(FFMPEG_LIBRARY_DIRS "${FFMPEG_PATH}/lib")

    # Propagate the FFmpeg libraries.
    target_link_libraries(
      ffmpeg_interface
      INTERFACE ${FFMPEG_LIBRARY_DIRS}/libavcodec.dylib
                ${FFMPEG_LIBRARY_DIRS}/libavformat.dylib
                ${FFMPEG_LIBRARY_DIRS}/libavfilter.dylib
                ${FFMPEG_LIBRARY_DIRS}/libavdevice.dylib
                ${FFMPEG_LIBRARY_DIRS}/libavutil.dylib
                ${FFMPEG_LIBRARY_DIRS}/libswresample.dylib
                ${FFMPEG_LIBRARY_DIRS}/libswscale.dylib)
    target_link_options(ffmpeg_interface INTERFACE "-Wl,-rpath,${ffmpeg-libs_SOURCE_DIR}")

  else()
    message(WARNING "Looking for system FFmpeg libraries")
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

    # Add liquid-dsp dependencies for Windows - use the precompiled library
    if(WIN32)
      # Add interface library which collects liquid-dsp dependencies
      if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x64")
        message(WARNING "64 bit architecture detected")
        set(ARCHITECTURE_NUMBER 64)
      else()
        set(ARCHITECTURE_NUMBER 32)
      endif()

      # Create an imported shared library target
      add_library(liquid_interface SHARED IMPORTED)
      set_target_properties(
        liquid_interface
        PROPERTIES
          IMPORTED_LOCATION
          "${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/lib/msvc/${ARCHITECTURE_NUMBER}/libliquid.dll" # The DLL for runtime
          IMPORTED_IMPLIB
          "${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/lib/msvc/${ARCHITECTURE_NUMBER}/libliquid.lib" # The .lib import library for linking
          INTERFACE_INCLUDE_DIRECTORIES "${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/lib/include")

      # Mark the dll for install
      install(
        FILES "${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/lib/msvc/${ARCHITECTURE_NUMBER}/libliquid.dll"
        DESTINATION ${CMAKE_INSTALL_BINDIR}
        COMPONENT bin)
    else()
      add_library(liquid_interface INTERFACE)
      # Add liquid-dsp dependencies for other platforms
      target_include_directories(
        liquid_interface INTERFACE $<BUILD_INTERFACE:${CPM_PACKAGE_liquid-dsp_SOURCE_DIR}/include>
                                   $<INSTALL_INTERFACE:include>)
      target_link_libraries(liquid_interface INTERFACE liquid)
    endif()
  endif()
  add_library(liquid::liquid ALIAS liquid_interface)

endfunction()

macro(add_flir_sdk_dependency)

  add_library(flir_sdk INTERFACE)
  add_library(flir::flir_sdk ALIAS flir_sdk)
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    cpmaddpackage(
      NAME
      flir-sdk
      GIT_TAG
      linux-2.6.0
      GITHUB_REPOSITORY
      MarlovOne/flir-sdk
      DOWNLOAD_ONLY
      TRUE)

    set(FLIR_SDK_FOUND TRUE)
    set(FLIR_SDK_DIR "${flir-sdk_SOURCE_DIR}/${CMAKE_SYSTEM_PROCESSOR}")
    set(FLIR_SDK_LIBRARY_DIRS "${FLIR_SDK_DIR}/lib")
    set(FLIR_SDK_INCLUDE_DIRS "${FLIR_SDK_DIR}/include")
    target_include_directories(flir_sdk INTERFACE ${FLIR_SDK_INCLUDE_DIRS})
    target_link_libraries(
      flir_sdk
      INTERFACE ${FLIR_SDK_LIBRARY_DIRS}/libatlas_c_sdk.so
                ${FLIR_SDK_LIBRARY_DIRS}/liblive666.so
                ${FLIR_SDK_LIBRARY_DIRS}/libavformat.so.58
                ${FLIR_SDK_LIBRARY_DIRS}/libavcodec.so.58
                ${FLIR_SDK_LIBRARY_DIRS}/libswscale.so.5
                ${FLIR_SDK_LIBRARY_DIRS}/libavutil.so.56
                ${FLIR_SDK_LIBRARY_DIRS}/libswresample.so.3)

  elseif(ANDROID)
    set(FLIR_SDK_FOUND FALSE)
  elseif(WIN32)
    cpmaddpackage(
      NAME
      flir-sdk
      GIT_TAG
      windows-2.6.0
      GITHUB_REPOSITORY
      MarlovOne/flir-sdk
      DOWNLOAD_ONLY
      TRUE)
    set(FLIR_SDK_FOUND TRUE)
    set(FLIR_SDK_DIR "${flir-sdk_SOURCE_DIR}/${CMAKE_VS_PLATFORM_NAME}")
    set(FLIR_SDK_LIBRARY_DIRS "${FLIR_SDK_DIR}/lib")
    set(FLIR_SDK_INCLUDE_DIRS "${FLIR_SDK_DIR}/include")
    target_include_directories(flir_sdk INTERFACE ${FLIR_SDK_INCLUDE_DIRS})

    # Create an imported target for the FLIR SDK library
    add_library(atlas_c_sdk SHARED IMPORTED)
    set_property(
      TARGET atlas_c_sdk
      PROPERTY IMPORTED_LOCATION
               "${FLIR_SDK_DIR}/bin/atlas_c_sdk.dll"
               "${FLIR_SDK_DIR}/bin/live666.dll"
               "${FLIR_SDK_DIR}/bin/avcodec-58.dll"
               "${FLIR_SDK_DIR}/bin/avdevice-58.dll"
               "${FLIR_SDK_DIR}/bin/avfilter-7.dll"
               "${FLIR_SDK_DIR}/bin/avformat-58.dll"
               "${FLIR_SDK_DIR}/bin/avutil-56.dll"
               "${FLIR_SDK_DIR}/bin/swscale-5.dll"
               "${FLIR_SDK_DIR}/bin/swresample-3.dll"
               "${FLIR_SDK_DIR}/bin/swscale-5.dll")
    set_property(TARGET atlas_c_sdk PROPERTY IMPORTED_IMPLIB "${FLIR_SDK_LIBRARY_DIRS}/atlas_c_sdk.lib")
    target_link_libraries(flir_sdk INTERFACE atlas_c_sdk)

  elseif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin" AND NOT IOS)
    cpmaddpackage(
      NAME
      flir-sdk
      GIT_TAG
      macos-2.6.0
      GITHUB_REPOSITORY
      MarlovOne/flir-sdk
      DOWNLOAD_ONLY
      TRUE)

    set(FLIR_SDK_FOUND TRUE)
    set(FLIR_SDK_DIR "${flir-sdk_SOURCE_DIR}/universal")
    set(FLIR_SDK_LIBRARY_DIRS "${FLIR_SDK_DIR}/lib")
    set(FLIR_SDK_INCLUDE_DIRS "${FLIR_SDK_DIR}/include")
    # target_include_directories(flir_sdk INTERFACE ${FLIR_SDK_INCLUDE_DIRS})

    target_link_libraries(
      flir_sdk
      INTERFACE "${FLIR_SDK_LIBRARY_DIRS}/libatlas_c_sdk.dylib"
                "${FLIR_SDK_LIBRARY_DIRS}/libavcodec.58.dylib"
                "${FLIR_SDK_LIBRARY_DIRS}/libavdevice.58.dylib"
                "${FLIR_SDK_LIBRARY_DIRS}/libavfilter.7.dylib"
                "${FLIR_SDK_LIBRARY_DIRS}/libavformat.58.dylib"
                "${FLIR_SDK_LIBRARY_DIRS}/libavutil.56.dylib"
                "${FLIR_SDK_LIBRARY_DIRS}/libswresample.3.dylib"
                "${FLIR_SDK_LIBRARY_DIRS}/liblive666.dylib"
                "${FLIR_SDK_LIBRARY_DIRS}/libswscale.5.dylib")
    target_link_options(flir_sdk INTERFACE "-Wl,-rpath,${FLIR_SDK_LIBRARY_DIRS}")

  elseif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS" OR IOS)
    set(FLIR_SDK_FOUND TRUE)

    cpmaddpackage(
      NAME
      flir-sdk
      GIT_TAG
      ios-2.6.0
      GITHUB_REPOSITORY
      MarlovOne/flir-sdk
      DOWNLOAD_ONLY
      TRUE)

    set(FLIR_SDK_DIR ${flir-sdk_SOURCE_DIR})

    # Add paths to frameworks
    set(METERLINK_FRAMEWORK ${FLIR_SDK_DIR}/MeterLink.xcframework)
    set(THERMALSDK_FRAMEWORK ${FLIR_SDK_DIR}/ThermalSDK.xcframework)
    set(LIBAVCODEC_FRAMEWORK ${FLIR_SDK_DIR}/libavcodec.58.dylib.xcframework)
    set(LIBAVDEVICE_FRAMEWORK ${FLIR_SDK_DIR}/libavdevice.58.dylib.xcframework)
    set(LIBAVFILTER_FRAMEWORK ${FLIR_SDK_DIR}/libavfilter.7.dylib.xcframework)
    set(LIBAVFORMAT_FRAMEWORK ${FLIR_SDK_DIR}/libavformat.58.dylib.xcframework)
    set(LIBAVUTIL_FRAMEWORK ${FLIR_SDK_DIR}/libavutil.56.dylib.xcframework)
    set(LIBSWRESAMPLE_FRAMEWORK ${FLIR_SDK_DIR}/libswresample.3.dylib.xcframework)
    set(LIBSWSCALE_FRAMEWORK ${FLIR_SDK_DIR}/libswscale.5.dylib.xcframework)
    set(LIBLIVE666_FRAMEWORK ${FLIR_SDK_DIR}/liblive666.dylib.xcframework)

    set(METERLINK_EXPECTED_HEADER_PATH "${METERLINK_FRAMEWORK}/ios-arm64/MeterLink.framework/Headers")
    set(THERMALSDK_EXPECTED_HEADER_PATH "${THERMALSDK_FRAMEWORK}/ios-arm64/ThermalSDK.framework/Headers")
    set(FLIR_SDK_INCLUDE_DIRS "${METERLINK_EXPECTED_HEADER_PATH}" "${THERMALSDK_EXPECTED_HEADER_PATH}")
    target_link_libraries(
      flir_sdk
      INTERFACE "${METERLINK_FRAMEWORK}"
                "${THERMALSDK_FRAMEWORK}"
                "${LIBAVCODEC_FRAMEWORK}"
                "${LIBAVDEVICE_FRAMEWORK}"
                "${LIBAVFILTER_FRAMEWORK}"
                "${LIBAVFORMAT_FRAMEWORK}"
                "${LIBAVUTIL_FRAMEWORK}"
                "${LIBSWRESAMPLE_FRAMEWORK}"
                "${LIBSWSCALE_FRAMEWORK}"
                "${LIBLIVE666_FRAMEWORK}")

  else()
    message(FATAL_ERROR "Unsupported platform")
  endif()

endmacro()
