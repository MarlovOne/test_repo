add_library(sample_library sample_library.cpp)

add_library(test_repo::sample_library ALIAS sample_library)

message(WARNING "SAMPLE_LIB FFMEG LIBRARIES ${FFMPEG_LIBRARIES}")
message(WARNING "SAMPLE_LIB FFMEG include ${FFMPEG_INCLUDE_DIRS}")

target_link_libraries(
  sample_library
  PRIVATE test_repo::test_repo_options
          test_repo::test_repo_warnings
          $<BUILD_INTERFACE:${OpenCV_LIBS}>
          $<BUILD_INTERFACE:spdlog::spdlog>
          $<BUILD_INTERFACE:Eigen3::Eigen>
          $<BUILD_INTERFACE:liquid::liquid>
          $<BUILD_INTERFACE:nlohmann_json::nlohmann_json>
          $<BUILD_INTERFACE:charls>
          $<BUILD_INTERFACE:pugixml::pugixml>
          $<BUILD_INTERFACE:${FFMPEG_LIBRARIES}>)

if(${FLIR_SDK_FOUND})
  target_compile_definitions(sample_library PUBLIC FLIR_SDK_FOUND=1)
else()
  target_compile_definitions(sample_library PUBLIC FLIR_SDK_FOUND=0)
endif()

if(${FLIR_SDK_FOUND})
  if(WIN32
     OR ${CMAKE_SYSTEM_NAME} MATCHES "Darwin"
     AND NOT IOS)
    message(STATUS "Linking flir_sdk as PUBLIC (Windows/macOS)")
    target_link_libraries(sample_library PUBLIC flir_sdk)
  else()
    message(STATUS "Linking flir_sdk as PRIVATE")
    target_link_libraries(sample_library PRIVATE flir_sdk)
  endif()
endif()

# If ffmpeg is a shared library (it is for windows and macos) then make it public to propagate to the parent projects
if(WIN32
   OR ${CMAKE_SYSTEM_NAME} MATCHES "Darwin"
   AND NOT IOS
   OR ANDROID)
  target_link_libraries(sample_library PUBLIC ffmpeg_interface)
else()
  target_link_libraries(sample_library PRIVATE ffmpeg_interface)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "iOS" OR IOS)
  message(STATUS "Linking frameworks for iOS")
  target_link_libraries(
    sample_library
    PRIVATE "-framework AVFoundation"
            "-framework UIKit"
            "-framework Foundation" # Added to resolve missing symbols
            "-framework CoreFoundation"
            "-framework CoreMedia"
            "-framework AudioToolbox"
            "-framework VideoToolbox"
            "-framework CoreVideo"
            "-liconv")
endif()

target_include_directories(
  sample_library ${WARNING_GUARD}
  PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
         $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>
         $<INSTALL_INTERFACE:include>
         $<BUILD_INTERFACE:${OpenCV_INCLUDE_DIRS}>
  PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include" $<BUILD_INTERFACE:${CPPYSTRUCT_SOURCE_DIR}/include>
          $<BUILD_INTERFACE:${FFMPEG_INCLUDE_DIRS}>
          $<BUILD_INTERFACE:${FLIR_SDK_INCLUDE_DIRS}>)

# Include ffmpeg definitions
target_compile_definitions(sample_library PRIVATE ${FFMPEG_DEFINITIONS})

set_target_properties(sample_library PROPERTIES VERSION ${PROJECT_VERSION} POSITION_INDEPENDENT_CODE ON)

if(WIN32 AND BUILD_SHARED_LIBS)
  # TODO(lmark): Replace this with autmatically generated export macros
  # TODO(lmark): hide visibility of all symbols except the ones we want to export
  target_compile_definitions(sample_library PRIVATE SAMPLE_LIBRARY_EXPORTS)
endif()

if(WIN32 AND BUILD_SHARED_LIBS)
  add_custom_command(
    TARGET sample_library
    PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:sample_library> $<TARGET_FILE_DIR:sample_library>
    COMMAND_EXPAND_LISTS)

endif()

if(WIN32)
    
  add_custom_command(
    TARGET sample_library
    PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:sample_library> $<TARGET_FILE_DIR:sample_library>
    COMMAND_EXPAND_LISTS)
 
  install(FILES $<TARGET_RUNTIME_DLLS:sample_library> DESTINATION bin)

  # Also install the FFmpeg import libraries (.lib files)
  install(
    FILES "${FFMPEG_LIBRARY_DIRS}/avcodec.lib"
          "${FFMPEG_LIBRARY_DIRS}/avformat.lib"
          "${FFMPEG_LIBRARY_DIRS}/avdevice.lib"
          "${FFMPEG_LIBRARY_DIRS}/avfilter.lib"
          "${FFMPEG_LIBRARY_DIRS}/avutil.lib"
          "${FFMPEG_LIBRARY_DIRS}/postproc.lib"
          "${FFMPEG_LIBRARY_DIRS}/swresample.lib"
          "${FFMPEG_LIBRARY_DIRS}/swscale.lib"
    DESTINATION lib)
  
  # install the flir-sdk shared libraries (.dll files)
  install(
    FILES "${FLIR_SDK_DIR}/bin/atlas_c_sdk.dll"
          "${FLIR_SDK_DIR}/bin/live666.dll"
          "${FLIR_SDK_DIR}/bin/avcodec-58.dll"
          "${FLIR_SDK_DIR}/bin/avdevice-58.dll"
          "${FLIR_SDK_DIR}/bin/avfilter-7.dll"
          "${FLIR_SDK_DIR}/bin/avformat-58.dll"
          "${FLIR_SDK_DIR}/bin/avutil-56.dll"
          "${FLIR_SDK_DIR}/bin/swscale-5.dll"
          "${FLIR_SDK_DIR}/bin/swresample-3.dll"
          "${FLIR_SDK_DIR}/bin/swscale-5.dll"
    DESTINATION bin)

endif()

if(ANDROID)
  # Install the FFmpeg shared libraries (.so files)
  install(
    FILES "${FFMPEG_LIBRARY_DIRS}/libavcodec.so"
          "${FFMPEG_LIBRARY_DIRS}/libavdevice.so"
          "${FFMPEG_LIBRARY_DIRS}/libavfilter.so"
          "${FFMPEG_LIBRARY_DIRS}/libavformat.so"
          "${FFMPEG_LIBRARY_DIRS}/libavutil.so"
          "${FFMPEG_LIBRARY_DIRS}/libpostproc.so"
          "${FFMPEG_LIBRARY_DIRS}/libswscale.so"
          "${FFMPEG_LIBRARY_DIRS}/libswresample.so"
    DESTINATION lib)

  # Need to install libc++_shared.so for Android
  set(ANDROID_STL c++_shared)
  include(${CMAKE_SOURCE_DIR}/cmake/modules/ndk-stl-config.cmake)

endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "iOS" OR IOS)
  # Install static libraries for iOS - FFMPEG
  # Note: install to a separate libraray - the currently used ios libraries containe multiple architectures and need to be manually stripped for arm64
  install(
    FILES "${FFMPEG_LIBRARY_DIRS}/libavcodec.a"
          "${FFMPEG_LIBRARY_DIRS}/libavdevice.a"
          "${FFMPEG_LIBRARY_DIRS}/libavfilter.a"
          "${FFMPEG_LIBRARY_DIRS}/libavformat.a"
          "${FFMPEG_LIBRARY_DIRS}/libavutil.a"
          "${FFMPEG_LIBRARY_DIRS}/libswresample.a"
          "${FFMPEG_LIBRARY_DIRS}/libswscale.a"
    DESTINATION ffmpeg/lib)
endif()

if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin" AND NOT IOS)
  # Install dynamic libraries for macOS - FFMPEG
  # add_dependencies(sample_library fix_ffmpeg_install_names)
  install(
    FILES ${FFMPEG_LIBRARY_DIRS}/libavcodec.dylib
          ${FFMPEG_LIBRARY_DIRS}/libavdevice.dylib
          ${FFMPEG_LIBRARY_DIRS}/libavfilter.dylib
          ${FFMPEG_LIBRARY_DIRS}/libavformat.dylib
          ${FFMPEG_LIBRARY_DIRS}/libavutil.dylib
          ${FFMPEG_LIBRARY_DIRS}/libswresample.dylib
          ${FFMPEG_LIBRARY_DIRS}/libswscale.dylib
    DESTINATION ffmpeg/lib)
  
  # TODO MAYBE HERE ???
  install(
    FILES ${FLIR_SDK_LIBRARY_DIRS}/libatlas_c_sdk.dylib
          ${FLIR_SDK_LIBRARY_DIRS}/libavcodec.58.134.100.dylib
          ${FLIR_SDK_LIBRARY_DIRS}/libavdevice.58.13.100.dylib
          ${FLIR_SDK_LIBRARY_DIRS}/libavfilter.7.110.100.dylib
          ${FLIR_SDK_LIBRARY_DIRS}/libavformat.58.76.100.dylib
          ${FLIR_SDK_LIBRARY_DIRS}/libavutil.56.70.100.dylib
          ${FLIR_SDK_LIBRARY_DIRS}/libswresample.3.9.100.dylib
          ${FLIR_SDK_LIBRARY_DIRS}/liblive666.dylib
          ${FLIR_SDK_LIBRARY_DIRS}/libswscale.5.9.100.dylib
    DESTINATION flir-sdk/lib)
endif()
