#! /bin/zsh

set -e
set -x

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Push to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

# Remove previous build and artifacts
rm -rf build/ios
rm -rf artifacts/ios

mkdir -p ./build/ios/opencv
mkdir -p ./install/ios/opencv
mkdir -p ./artifacts/ios

# Build the project
cmake \
    -S test_repo \
    -B build/ios \
    -G Xcode \
    -DCMAKE_TOOLCHAIN_FILE=./cmake/toolchain/ios.toolchain.cmake \
    -DPLATFORM=OS64 \
    -DDEPLOYMENT_TARGET=13.0 \
    -Dnetxten_PACKAGING_MAINTAINER_MODE:BOOL=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -Dtest_repo_ENABLE_IPO=OFF \
    -DEigen3_DIR="/opt/homebrew/Cellar/eigen/3.4.0_1/share/eigen3/cmake"

cmake \
    --build ./build/ios \
    --config Release

# Install the project
mkdir -p artifacts/ios
cmake --install ./build/ios --prefix $(realpath ./artifacts/ios)

# iOS fat library contains lib for 2 destinations: iOS device and simulator
# we need to split them before combining into xcframework to avoid error: "binaries with multiple platforms are not supported"
# mkdir -p artifacts/ios/lib/x86_64
# lipo artifacts/ios/lib/libsample_library.a -thin x86_64 -o artifacts/ios/lib/x86_64/libsample_library.a
# mkdir -p artifacts/ios/lib/arm64
# lipo artifacts/ios/lib/libsample_library.a -thin arm64 -o artifacts/ios/lib/arm64/libsample_library.a

# Create the xcframework
# xcodebuild \
#     -create-xcframework \
#     -library artifacts/ios/lib/arm64/libsample_library.a \
#     -headers artifacts/ios/include \
#     -library artifacts/ios/lib/x86_64/libsample_library.a \
#     -headers artifacts/ios/include \
#     -output artifacts/ios/libsample_library.xcframework

libtool -static -o artifacts/ios/lib/libsample_library_combined.a  \
    artifacts/ios/lib/libsample_library.a \
    install/ios/opencv/lib/libopencv_core.a \
    install/ios/opencv/lib/libopencv_imgproc.a \
    install/ios/opencv/lib/opencv4/3rdparty/libittnotify.a \
    install/ios/opencv/lib/opencv4/3rdparty/liblibjpeg-turbo.a \
    install/ios/opencv/lib/opencv4/3rdparty/libzlib.a

xcodebuild \
    -create-xcframework \
    -library artifacts/ios/lib/libsample_library_combined.a \
    -headers artifacts/ios/include \
    -output artifacts/ios/libsample_library.xcframework
 
# Copy the artifact to the ffi plugin
rm -rf ./blabla/ios/libsample_library.xcframework
mkdir -p ./blabla/ios/libsample_library.xcframework
cp -rf ./artifacts/ios/libsample_library.xcframework ./blabla/ios/libsample_library.xcframework

popd > /dev/null
