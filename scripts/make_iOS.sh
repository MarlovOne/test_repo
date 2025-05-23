#! /bin/zsh

set -x
set -e

# Default parameters
BUILD_TYPE="Release"
MAINTAINER_MODE="ON"
GIT_SHA=""
ENABLE_COVERAGE="FALSE"
BUILD_DIR=""  # If not provided, will default to build/ios

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
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

# export CPM_SOURCE_CACHE="$HOME/.cpm_cache"

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Navigate to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

# Set up the environment
. ./scripts/setup_environment.sh

# Remove previous build and artifacts
rm -rf build/ios
rm -rf artifacts/ios

# Determine the build directory
if [[ -z "${BUILD_DIR}" ]]; then
    BUILD_DIR="$PWD/build/ios"
fi

# Create necessary directories
# mkdir -p "$BUILD_DIR"
mkdir -p ./install/ios
mkdir -p ./artifacts/ios

# Configure the project with CMake using the Xcode generator
cmake \
    -G "Ninja Multi-Config" \
    -S test_repo \
    -B "$BUILD_DIR" \
    -DCMAKE_TOOLCHAIN_FILE=./cmake/toolchain/ios.toolchain.cmake \
    -DPLATFORM=OS64 \
    -DDEPLOYMENT_TARGET=13.0 \
    -Dtest_repo_PACKAGING_MAINTAINER_MODE:BOOL=${MAINTAINER_MODE} \
    -DBUILD_SHARED_LIBS=OFF \
    -Dtest_repo_ENABLE_IPO=OFF \
    -Dtest_repo_ENABLE_COVERAGE:BOOL=${ENABLE_COVERAGE} \
    -DGIT_SHA=${GIT_SHA} \
    -DCMAKE_BUILD_TYPE=${BUILD_TYPE}

# Build the project
cmake \
    --build "$BUILD_DIR" \
    --config ${BUILD_TYPE} \
    --verbose

# Install the project
mkdir -p artifacts/ios
cmake \
    --install "$BUILD_DIR" \
    --prefix $(realpath ./artifacts/ios) \
    --config ${BUILD_TYPE}

FFMPEG_LIB_DIR="$(pwd)/artifacts/ios/ffmpeg/lib"
THIN_FFMPEG_LIB_DIR="$(pwd)/artifacts/ios/thin/arm64/ffmpeg/lib"
mkdir -p $THIN_FFMPEG_LIB_DIR

# Thin all libraries in artifacts/ios/lib for arm64
for lib in $(find "${FFMPEG_LIB_DIR}" -type f -name "*.a"); do
  echo "Thinning ${lib} for arm64..."
  lipo -thin arm64 "${lib}" -output "${THIN_FFMPEG_LIB_DIR}/$(basename "${lib}")"
done

# Merge the static libraries
libtool -static -o artifacts/ios/lib/libtest_repo.a \
  $(find "$(pwd)/artifacts/ios/lib" -type f -name "*.a") \
  $(find "$THIN_FFMPEG_LIB_DIR" -type f -name "*.a") \
  $(find "$(pwd)/"$BUILD_DIR"/_deps/opencv-staticlib-src/arm64/lib" -type f -name "*.a")

# Combine the headers
COMBINED_HEADERS=artifacts/ios/combined_headers/
mkdir -p $COMBINED_HEADERS
mkdir -p $COMBINED_HEADERS/Eigen/
cp -R artifacts/ios/include/* $COMBINED_HEADERS
cp -R artifacts/ios/opencv4/* $COMBINED_HEADERS
cp -R artifacts/ios/Eigen/* $COMBINED_HEADERS/Eigen/

# Create the xcframework
xcodebuild \
    -create-xcframework \
    -library artifacts/ios/lib/libtest_repo.a \
    -headers $COMBINED_HEADERS \
    -output artifacts/ios/libsample_library.xcframework
 
# Copy the artifact to the ffi plugin
setopt nonomatch
rm -rf ./blabla/ios/libsample_library.xcframework
cp -rf ./artifacts/ios/libsample_library.xcframework ./blabla/ios/libsample_library.xcframework

FLIR_SDK_PATH="$(pwd)/${BUILD_DIR}/_deps/flir-sdk-src"
# Copy FLIR SDK frameworks to the blabla iOS directory
if [ -d "$FLIR_SDK_PATH" ]; then
  echo "Copying FLIR ThermalSDK frameworks to blabla/ios..."
  cp -R "$FLIR_SDK_PATH/ThermalSDK.xcframework" ./blabla/ios/ || true
  cp -R "$FLIR_SDK_PATH/MeterLink.xcframework" ./blabla/ios/ || true
else
  echo "Warning: FLIR_SDK_PATH not set or directory doesn't exist. FLIR SDK frameworks not copied."
  echo "Please make sure to set --flir-sdk-path when running this script."
fi

popd > /dev/null
