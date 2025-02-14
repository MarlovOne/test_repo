#! /bin/bash

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Push to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

install_opencv_android() {

  # Define installation path
  INSTALL_DIR="./install/Android/opencv"
  SDK_URL="https://github.com/opencv/opencv/releases/download/4.11.0/opencv-4.11.0-android-sdk.zip"

  # Create installation directory
  mkdir -p "$INSTALL_DIR"

  # Download OpenCV Android SDK
  echo "Downloading OpenCV Android SDK..."
  curl -L "$SDK_URL" -o opencv-android-sdk.zip

  # Extract the archive
  echo "Extracting OpenCV Android SDK..."
  unzip -q opencv-android-sdk.zip -d "$INSTALL_DIR"
  
  # Cleanup
  rm opencv-android-sdk.zip

  echo "OpenCV Android SDK installed at: $INSTALL_DIR"

}

install_opencv_android

popd > /dev/null