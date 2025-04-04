#! /bin/bash

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Push to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

install_opencv_macos() {
  git clone --depth 1 --branch 4.11.0 https://github.com/opencv/opencv.git

  rm -rf ./build/iOS/opencv
  rm -rf ./install/iOS/opencv

  # Set architecture-specific CMake flags
  cmake -G Xcode \
    -S opencv \
    -B ./build/iOS/opencv \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13 \
    -DBUILD_OBJC=OFF \
    -DSWIFT_DISABLED=1 \
    -DBUILD_opencv_apps=OFF \
    -DBUILD_LIST=core,imgproc,features2d,flann,calib3d,videoio,video,highgui \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_opencv_flann=ON \
    -DBUILD_opencv_calib3d=ON \
    -DBUILD_opencv_dnn=OFF \
    -DBUILD_opencv_features2d=ON \
    -DBUILD_opencv_photo=OFF \
    -DBUILD_opencv_objdetect=OFF \
    -DBUILD_opencv_ml=OFF \
    -DBUILD_opencv_video=ON \
    -DBUILD_opencv_videoio=ON \
    -DBUILD_opencv_highgui=ON \
    -DBUILD_opencv_gapi=OFF \
    -DWITH_CAROTENE=OFF \
    -DWITH_JASPER=OFF \
    -DWITH_IMGCODEC_HDR=OFF \
    -DWITH_IMGCODEC_PFM=OFF \
    -DWITH_IMGCODEC_PXM=OFF \
    -DWITH_IMGCODEC_SUNRASTER=OFF \
    -DWITH_QUIRC=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_DOCS=OFF \
    -DBUILD_OPENEXR=ON \
    -DBUILD_JPEG=ON \
    -DBUILD_PNG=ON \
    -DBUILD_ZLIB=ON \
    -DBUILD_TIFF=ON \
    -DBUILD_OPENJPEG=ON \
    -DBUILD_WEBP=ON \
    -DBUILD_PROTOBUFF=OFF \
    -DWITH_PROTOBUF=OFF \
    -DWITH_ADE=OFF

  # Run CMake and build
  cmake --build ./build/iOS/opencv --verbose --config Release
  cmake --install ./build/iOS/opencv --prefix ./install/iOS/opencv

  # Uncomment if you want to clean up
  # rm -rf ./opencv
}

install_opencv_macos

popd > /dev/null