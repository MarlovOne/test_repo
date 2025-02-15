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

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Navigate to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

# Remove previous build and artifacts
rm -rf build/ios
rm -rf artifacts/ios

# Determine the build directory
if [[ -z "${BUILD_DIR}" ]]; then
    BUILD_DIR="$PWD/build/ios"
fi

# Create necessary directories
mkdir -p "$BUILD_DIR"
mkdir -p ./install/ios
mkdir -p ./artifacts/ios

# Configure the project with CMake using the Xcode generator
cmake \
    -S test_repo \
    -B "$BUILD_DIR" \
    -G Xcode \
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
    --prefix $(realpath ./artifacts/ios)

# Merge the static libraries
libtool -static -o artifacts/ios/lib/libsample_library_combined.a  \
    artifacts/ios/lib/libsample_library.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64/lib/libopencv_core.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64/lib/libopencv_imgproc.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64/lib/opencv4/3rdparty/libittnotify.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64/lib/opencv4/3rdparty/liblibjpeg-turbo.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64/lib/opencv4/3rdparty/libzlib.a

# Create the xcframework
xcodebuild \
    -create-xcframework \
    -library artifacts/ios/lib/libsample_library_combined.a \
    -headers artifacts/ios/include \
    -output artifacts/ios/libsample_library.xcframework
 
# Copy the artifact to the ffi plugin
rm -rf ./blabla/ios/libsample_library.xcframework
cp -rf ./artifacts/ios/libsample_library.xcframework ./blabla/ios/libsample_library.xcframework

popd > /dev/null
