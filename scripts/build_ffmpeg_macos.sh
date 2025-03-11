#!/usr/bin/env zsh
set -euo pipefail

# Function to check if a command exists
check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo "Error: Required command '$1' not found in PATH." >&2
    exit 1
  fi
}

# Check essential commands
check_command git
check_command make
check_command nproc
check_command lipo

# Check cross-compilers (adjust names if needed)
check_command o64-clang
check_command aarch64-apple-darwin-clang

# Directories
FFMPEG_DIR="${PWD}/ffmpeg"
BUILD_DIR="${PWD}/build"
INSTALL_DIR="${PWD}/install/macOS/ffmpeg"
LIBS=("libavcodec.a" "libavformat.a" "libavutil.a" "libswscale.a" "libswresample.a")

# Clone FFmpeg if source directory does not exist
if [ ! -d "$FFMPEG_DIR" ]; then
  echo "FFmpeg source not found. Cloning..."
  git clone https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_DIR"
fi

# Create build directories for both architectures
mkdir -p "$BUILD_DIR/x86_64" "$BUILD_DIR/arm64"
mkdir -p "$INSTALL_DIR/lib" "$INSTALL_DIR/include"

# Function to build FFmpeg for a given architecture
build_ffmpeg() {
  local arch="$1"
  local prefix="$2"
  local cc="$3"

  echo "Building FFmpeg for ${arch}..."
  cd "$FFMPEG_DIR"
  
  # Clean previous build config; ignore errors if no clean is needed
  make distclean 2>/dev/null || true

  # Run configure for the given architecture
  ./configure \
    --prefix="$prefix" \
    --arch="$arch" \
    --target-os=darwin \
    --enable-static \
    --disable-shared \
    --disable-debug \
    --disable-optimizations \
    --cc="$cc"

  # Build and install
  make -j"$(nproc)"
  make install
}

echo "trigger"

# Build for x86_64 using the macOS cross-compiler
build_ffmpeg "x86_64" "$BUILD_DIR/x86_64" "o64-clang"

# Build for arm64 using the macOS cross-compiler
build_ffmpeg "arm64" "$BUILD_DIR/arm64" "aarch64-apple-darwin-clang"

# Create universal libraries using lipo
echo "Creating universal libraries..."
for lib in "${LIBS[@]}"; do
  X86_LIB="$BUILD_DIR/x86_64/lib/$lib"
  ARM_LIB="$BUILD_DIR/arm64/lib/$lib"
  if [ -f "$X86_LIB" ] && [ -f "$ARM_LIB" ]; then
    lipo -create "$X86_LIB" "$ARM_LIB" -output "$INSTALL_DIR/lib/$lib"
    echo "Created universal ${lib}"
  else
    echo "Warning: ${lib} not found for both architectures; skipping..."
  fi
done

# Copy include files (headers are architecture independent)
echo "Copying include files..."
if [ -d "$BUILD_DIR/x86_64/include" ]; then
  cp -R "$BUILD_DIR/x86_64/include/"* "$INSTALL_DIR/include/"
else
  echo "Error: Include directory not found in $BUILD_DIR/x86_64/include" >&2
  exit 1
fi

echo "Universal FFmpeg libraries and headers have been installed to:"
echo "  $INSTALL_DIR"