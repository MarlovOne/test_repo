#! /bin/bash

set -x
set -e

# Default parameters
ARCHS_ALL=("arm64-v8a" "armeabi-v7a" "x86" "x86_64")
ARCHS=("${ARCHS_ALL[@]}")
BUILD_TYPE="Release"
MAINTAINER_MODE="ON"
GIT_SHA=""
ENABLE_COVERAGE="FALSE"
BUILD_DIR=""  # If not provided, will default to build/android/<arch>

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --arch)
      shift
      if [[ -n "$1" ]]; then
        ARCHS=("$1")  # Override ARCHS with the selected architecture
      else
        echo "Error: Missing argument for --arch option"
        exit 1
      fi
      ;;
    --build-type)
      shift
      if [[ -n "$1" ]]; then
         BUILD_TYPE="$1"
      else
         echo "Error: Missing argument for --build-type option"
         exit 1
      fi
      ;;
    --maintainer-mode)
      shift
      if [[ -n "$1" ]]; then
         MAINTAINER_MODE="$1"
      else
         echo "Error: Missing argument for --maintainer-mode option"
         exit 1
      fi
      ;;
    --git-sha)
      shift
      if [[ -n "$1" ]]; then
         GIT_SHA="$1"
      else
         echo "Error: Missing argument for --git-sha option"
         exit 1
      fi
      ;;
    --enable-coverage)
      shift
      if [[ -n "$1" ]]; then
         ENABLE_COVERAGE="$1"
      else
         echo "Error: Missing argument for --enable-coverage option"
         exit 1
      fi
      ;;
    --build-dir)
      shift
      if [[ -n "$1" ]]; then
         BUILD_DIR="$1"
      else
         echo "Error: Missing argument for --build-dir option"
         exit 1
      fi
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Push to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

# Remove previous build and artifacts
rm -rf build/android
rm -rf artifacts/android

for ARCH in "${ARCHS[@]}"; do
    
    # Use provided BUILD_DIR if available; otherwise, default to build/android/<arch>
    if [[ -z "${BUILD_DIR}" ]]; then
        BUILD_DIR="$PWD/build/android/${ARCH}"
    fi

    # Build the project
    cmake \
        -S test_repo \
        -B "${BUILD_DIR}" \
        -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="${ARCH}" \
        -DANDROID_PLATFORM=21 \
        -Dtest_repo_PACKAGING_MAINTAINER_MODE:BOOL=${MAINTAINER_MODE} \
        -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
        -DBUILD_SHARED_LIBS=ON \
        -Dtest_repo_ENABLE_COVERAGE:BOOL=${ENABLE_COVERAGE} \
        -DGIT_SHA:STRING=${GIT_SHA}
        
    cmake \
        --build "${BUILD_DIR}" \
        --config ${BUILD_TYPE} \
        --verbose

    # Install the project
    mkdir -p artifacts/android/${ARCH}
    cmake \
        --install "${BUILD_DIR}" \
        --prefix "$(realpath ./artifacts/android/${ARCH})"

    # Copy the artifact to the ffi plugin
    mkdir -p ./blabla/android/lib/${ARCH}
    cp -rf ./artifacts/android/${ARCH}/* ./blabla/android/lib/${ARCH}/

done

popd > /dev/null