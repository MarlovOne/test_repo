#! /bin/zsh

set -x
set -e

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

# Setup the environment
. ./scripts/setup_environment.sh

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
  -DGIT_SHA:STRING=${GIT_SHA}

# Build the project
cmake \
    --build "$BUILD_DIR" \
    --config ${BUILD_TYPE}

# Install the project
mkdir -p artifacts/macos
cmake \
    --install "$BUILD_DIR" \
    --config ${BUILD_TYPE} \
    --prefix $(realpath ./artifacts/macos)

# TODO(lmark): I don't like the approach of merging the static libraries
# 1) Add this command as a post-build step in CMakeLists
# 2) Figure out how to put a shared library in an Xcode framework
# Merge the static libraries
libtool -static -o artifacts/macos/lib/libtest_repo.a \
  $(find "$(pwd)/artifacts/macos/lib" -type f -name "*.a") \
  $(find "$(pwd)/"$BUILD_DIR"/_deps/opencv-staticlib-src/arm64-x64/lib" -type f -name "*.a")

# Combine the headers
COMBINED_HEADERS=artifacts/macos/combined_headers/
mkdir -p $COMBINED_HEADERS
mkdir -p $COMBINED_HEADERS/Eigen/
cp -R artifacts/macos/include/* $COMBINED_HEADERS
cp -R artifacts/macos/opencv4/* $COMBINED_HEADERS
cp -R artifacts/macos/Eigen/* $COMBINED_HEADERS/Eigen/

# Create the xcframework
xcodebuild \
    -create-xcframework \
    -library artifacts/macos/lib/libtest_repo.a \
    -headers $COMBINED_HEADERS \
    -output artifacts/macos/libsample_library.xcframework

# Copy the artifact to the ffi plugin
setopt nonomatch
rm -rf ./blabla/macos/libsample_library.xcframework
cp -rf ./artifacts/macos/libsample_library.xcframework ./blabla/macos/libsample_library.xcframework

# --- Fix Dylib Linkage ---
# Define path to the artifact directory created by CMake install
DYLIB_ARTIFACT_PATH="./artifacts/macos/flir-sdk/lib" # Adjust subpath if needed

# Define path to the fixing script
FIX_SCRIPT_PATH="./scripts/fix_macos_dylibs.zsh" # Adjust path to where you saved the script

# Check if the script exists and is executable
if [ ! -x "$FIX_SCRIPT_PATH" ]; then
    echo "ERROR: Dylib fix script not found or not executable at $FIX_SCRIPT_PATH"
    exit 1
fi

echo "Running dylib fixing script on $DYLIB_ARTIFACT_PATH..."
# Execute the Zsh script, passing the artifact directory path
# Use 'zsh' explicitly if '.' might not be in PATH or script isn't executable by default shell
zsh "$FIX_SCRIPT_PATH" "$DYLIB_ARTIFACT_PATH" || { echo "ERROR: Dylib fixing script failed."; exit 1; }
echo "Dylib fixing script finished successfully."

# --- Rest of your script ---
echo "Continuing with macOS artifact preparation..."

# Copy ffmpeg dylibs
mkdir -p ./blabla/macos/dylibs
cp -rf ./artifacts/macos/ffmpeg/lib/* ./blabla/macos/dylibs/
cp -rf ./artifacts/macos/flir-sdk/lib/* ./blabla/macos/dylibs/

echo "make_macos.sh completed."
popd > /dev/null
exit 0
