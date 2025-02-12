#! /bin/zsh

# Exit immediatelly if a command exits with a non-zero status
set -e

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Push to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

# Remove previous build and artifacts
rm -rf build/macos
rm -rf artifacts/macos
  
mkdir -p ./build/macos/opencv
mkdir -p ./install/macos/opencv
mkdir -p ./artifacts/macos

# Build the project
cmake \
    -G Xcode \
    -S test_repo \
    -B build/macos \
    -DBUILD_SHARED_LIBS=OFF \
    -Dtest_repo_ENABLE_IPO=OFF \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -Dtest_repo_PACKAGING_MAINTAINER_MODE:BOOL=ON \
    -Dtest_repo_ENABLE_COVERAGE:BOOL=OFF
cmake \
    --build ./build/macos \
    --config Release

# Install the project
mkdir -p artifacts/macos
cmake \
    --install ./build/macos \
    --prefix $(realpath ./artifacts/macos)

# Merge the static libraries
libtool -static -o artifacts/macos/lib/libsample_library_combined.a  \
    artifacts/macos/lib/libsample_library.a \
    install/macos/opencv/lib/libopencv_core.a \
    install/macos/opencv/lib/libopencv_imgproc.a \
    install/macos/opencv/lib/opencv4/3rdparty/libittnotify.a \
    install/macos/opencv/lib/opencv4/3rdparty/liblibjpeg-turbo.a \
    install/macos/opencv/lib/opencv4/3rdparty/libzlib.a

# Create the xcframework
xcodebuild \
    -create-xcframework \
    -library artifacts/macos/lib/libsample_library_combined.a \
    -headers artifacts/macos/include \
    -output artifacts/macos/libsample_library.xcframework

# Copy the artifact to the ffi plugin
rm -rf ./blabla/macos/libsample_library.xcframework
cp -rf ./artifacts/macos/libsample_library.xcframework ./blabla/macos/libsample_library.xcframework

popd > /dev/null