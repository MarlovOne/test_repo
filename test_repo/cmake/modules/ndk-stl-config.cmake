# Copy shared STL files to Android Studio output directory so they can be
# packaged in the APK.
# Usage:
#
#   find_package(ndk-stl REQUIRED)
#
# or
#
#   find_package(ndk-stl REQUIRED PATHS ".")
# https://github.com/jomof/ndk-stl/blob/master/ndk-stl-config.cmake

if(NOT
   ${ANDROID_STL}
   MATCHES
   "_shared")
  return()
endif()

function(configure_shared_stl lib_path so_base)
  message("Configuring STL ${so_base} for ${ANDROID_ABI}")
  configure_file("${ANDROID_NDK}/sources/cxx-stl/${lib_path}/libs/${ANDROID_ABI}/lib${so_base}.so"
                 "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib${so_base}.so" COPYONLY)
endfunction()

# Choose the appropriate prebuilt directory based on host platform.
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
  set(PLATFORM_DIR "darwin-x86_64")
else()
  set(PLATFORM_DIR "linux-x86_64")
endif()

if("${ANDROID_STL}" STREQUAL "libstdc++")
  # The default minimal system C++ runtime library.
elseif("${ANDROID_STL}" STREQUAL "gabi++_shared")
  # The GAbi++ runtime (shared).
  message(FATAL_ERROR "gabi++_shared was not configured by ndk-stl package")
elseif("${ANDROID_STL}" STREQUAL "stlport_shared")
  # The STLport runtime (shared).
  configure_shared_stl("stlport" "stlport_shared")
elseif("${ANDROID_STL}" STREQUAL "gnustl_shared")
  # The GNU STL (shared).
  configure_shared_stl("gnu-libstdc++/4.9" "gnustl_shared")
elseif("${ANDROID_STL}" STREQUAL "c++_shared")
  # The LLVM libc++ runtime (shared).
  # Map ANDROID_ABI to the sysroot subdirectory name.
  if("${ANDROID_ABI}" STREQUAL "arm64-v8a")
    set(ARCH_DIR "aarch64-linux-android")
  elseif("${ANDROID_ABI}" STREQUAL "armeabi-v7a")
    set(ARCH_DIR "arm-linux-androideabi")
  elseif("${ANDROID_ABI}" STREQUAL "x86")
    set(ARCH_DIR "i686-linux-android")
  elseif("${ANDROID_ABI}" STREQUAL "x86_64")
    set(ARCH_DIR "x86_64-linux-android")
  else()
    message(FATAL_ERROR "Unsupported ANDROID_ABI: ${ANDROID_ABI}")
  endif()
  message("Configuring STL c++_shared for ${ANDROID_ABI} (mapped to ${ARCH_DIR})")
  set(COPY_SOURCE_PATH
      "${ANDROID_NDK}/toolchains/llvm/prebuilt/${PLATFORM_DIR}/sysroot/usr/lib/${ARCH_DIR}/libc++_shared.so")
  set(COPY_DESTIONATION_PATH "${CMAKE_BINARY_DIR}/lib/libc++_shared.so")
  message(STATUS "Copying ${COPY_SOURCE_PATH} to ${COPY_DESTIONATION_PATH}")
  configure_file(${COPY_SOURCE_PATH} ${COPY_DESTIONATION_PATH} COPYONLY)
  install(FILES ${COPY_DESTIONATION_PATH} DESTINATION lib)
else()
  message(FATAL_ERROR "STL configuration ANDROID_STL=${ANDROID_STL} is not supported")
endif()
