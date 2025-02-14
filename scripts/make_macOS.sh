#! /bin/zsh

# Default parameters
BUILD_TYPE="Release"
MAINTAINER_MODE="ON"
GIT_SHA=""
ENABLE_COVERAGE="FALSE"
BUILD_DIR="build/macos/backend"

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
        ENABLE_COVERAGE="$1"  # Set the enable coverage flag (e.g., TRUE or FALSE)
      else
        echo "Error: Missing argument for --enable-coverage option"
        exit 1
      fi
      ;;
    --build-dir)
      shift
      if [[ -n "$1" ]]; then
        BUILD_DIR="$1"  # Set the base build directory
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
rm -rf "$BUILD_DIR"
rm -rf artifacts/macos

# Configure the project with CMake
cmake \
   -S test_repo \
   -B "$BUILD_DIR" \
   -DBUILD_SHARED_LIBS=OFF \
   -Dtest_repo_ENABLE_IPO=OFF \
   -DCMAKE_BUILD_TYPE:STRING=${BUILD_TYPE} \
   -Dtest_repo_PACKAGING_MAINTAINER_MODE:BOOL=${MAINTAINER_MODE} \
   -Dtest_repo_ENABLE_COVERAGE:BOOL=${ENABLE_COVERAGE} \
   -DGIT_SHA=${GIT_SHA}

# Build the project
cmake \
    --build "$BUILD_DIR" \
    --config ${BUILD_TYPE}

# Install the project
mkdir -p artifacts/macos
cmake \
    --install "$BUILD_DIR" \
    --prefix $(realpath ./artifacts/macos)

# TODO(lmark): I don't like the approach of merging the static libraries
# 1) Add this command as a post-build step in CMakeLists
# 2) Figure out how to put a shared library in an Xcode framework
# Merge the static libraries
libtool -static -o artifacts/macos/lib/libsample_library_combined.a  \
    artifacts/macos/lib/libsample_library.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64-x64/lib/libopencv_core.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64-x64/lib/libopencv_imgproc.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64-x64/lib/opencv4/3rdparty/libittnotify.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64-x64/lib/opencv4/3rdparty/liblibjpeg-turbo.a \
    "$BUILD_DIR"/_deps/opencv-staticlib-src/arm64-x64/lib/opencv4/3rdparty/libzlib.a

# Create the xcframework
xcodebuild \
    -create-xcframework \
    -library artifacts/macos/lib/libsample_library_combined.a \
    -headers artifacts/macos/include \
    -output artifacts/macos/libsample_library.xcframework

# Copy the artifact to the ffi plugin
rm -rf ./eperlium/macos/libsample_library.xcframework
cp -rf ./artifacts/macos/libsample_library.xcframework ./eperlium/macos/libsample_library.xcframework

popd > /dev/null