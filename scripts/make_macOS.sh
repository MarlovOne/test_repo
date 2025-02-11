#! /bin/zsh

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Push to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

# Remove previous build and artifacts
rm -rf build/macOS
rm -rf artifacts/macOS
  
mkdir -p ./build/macOS/opencv
mkdir -p ./install/macOS/opencv

# Build the project
cmake \
    -G Xcode \
    -S test_repo \
    -B build/macOS \
    -DBUILD_SHARED_LIBS=OFF \
    -Dtest_repo_ENABLE_IPO=OFF \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -Dtest_repo_PACKAGING_MAINTAINER_MODE:BOOL=ON \
    -Dtest_repo_ENABLE_COVERAGE:BOOL=OFF
cmake \
    --build ./build/macOS \
    --config Release

# Install the project
mkdir -p artifacts/macOS
cmake \
    --install ./build/macOS \
    --prefix $(realpath ./artifacts/macOS)

# Create the xcframework
xcodebuild \
    -create-xcframework \
    -library artifacts/macOS/lib/libsample_library.a \
    -headers artifacts/macOS/include \
    -output artifacts/macOS/libsample_library.xcframework

# Copy the artifact to the ffi plugin
rm -rf ./eperlium/macos/libsample_library.xcframework
cp -rf ./artifacts/macos/libsample_library.xcframework ./eperlium/macos/libsample_library.xcframework

popd > /dev/null