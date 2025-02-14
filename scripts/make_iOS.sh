#! /bin/zsh

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
    -S api \
    -B build/ios \
    -G Xcode \
    -DCMAKE_TOOLCHAIN_FILE=./cmake/toolchain/ios.toolchain.cmake \
    -DPLATFORM=OS64 \
    -DDEPLOYMENT_TARGET=13.0 \
    -Dtest_repo_PACKAGING_MAINTAINER_MODE:BOOL=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -Dtest_repo_ENABLE_IPO=OFF
cmake \
    --build ./build/ios \
    --config Release

# Install the project
mkdir -p artifacts/ios
cmake \
    --install ./build/ios \
    --prefix $(realpath ./artifacts/ios)

# # TODO(lmark): Add OpenCV as x64 library for iOS
# # Comment this out as we're only building for arm64 - OpenCV is unable to be built as combine library
# # iOS fat library contains lib for 2 destinations: iOS device and simulator
# # we need to split them before combining into xcframework to avoid error: "binaries with multiple platforms are not supported"
# mkdir -p artifacts/ios/lib/x86_64
# lipo artifacts/ios/lib/libsample_library.a -thin x86_64 -o artifacts/ios/lib/x86_64/libsample_library.a
# mkdir -p artifacts/ios/lib/arm64
# lipo artifacts/ios/lib/libsample_library.a -thin arm64 -o artifacts/ios/lib/arm64/libsample_library.a

# Merge the static libraries
libtool -static -o artifacts/ios/lib/libsample_library_combined.a  \
    artifacts/ios/lib/libsample_library.a \
    build/ios/backend/_deps/opencv-staticlib-src/arm64/lib/libopencv_core.a \
    build/ios/backend/_deps/opencv-staticlib-src/arm64/lib/libopencv_imgproc.a \
    build/ios/backend/_deps/opencv-staticlib-src/arm64/lib/opencv4/3rdparty/libittnotify.a \
    build/ios/backend/_deps/opencv-staticlib-src/arm64/lib/opencv4/3rdparty/liblibjpeg-turbo.a \
    build/ios/backend/_deps/opencv-staticlib-src/arm64/lib/opencv4/3rdparty/libzlib.a

# Create the xcframework
xcodebuild \
    -create-xcframework \
    -library artifacts/ios/lib/libsample_library_combined.a \
    -headers artifacts/ios/include \
    -output artifacts/ios/libsample_library.xcframework
 
# Copy the artifact to the ffi plugin
rm -rf ./eperlium/ios/libsample_library.xcframework
cp -rf ./artifacts/ios/libsample_library.xcframework ./eperlium/ios/libsample_library.xcframework

popd > /dev/null
