#! /bin/zsh

# Default architectures, build type, maintainer mode, git sha, coverage flag, and build directory
ARCHS_ALL=("x86_64" "aarch64")
ARCHS=("${ARCHS_ALL[@]}")
BUILD_TYPE="Release"
MAINTAINER_MODE="ON"
GIT_SHA=""
ENABLE_COVERAGE="FALSE"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --arch)
      shift
      if [[ -n "$1" ]]; then
        ARCHS=("$1")  # Override ARCHS with the selected architecture
      else
        echo "Error: Missing argument for --arch option"
        exit 1
      fi
      ;;
    --build-type)
      shift
      if [[ -n "$1" ]]; then
        BUILD_TYPE="$1"  # Set the build type
      else
        echo "Error: Missing argument for --build-type option"
        exit 1
      fi
      ;;
    --maintainer-mode)
      shift
      if [[ -n "$1" ]]; then
        MAINTAINER_MODE="$1"  # Set the maintainer mode (e.g., ON or OFF)
      else
        echo "Error: Missing argument for --maintainer-mode option"
        exit 1
      fi
      ;;
    --git-sha)
      shift
      if [[ -n "$1" ]]; then
        GIT_SHA="$1"  # Set the git sha
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

# Check if ARCHS contains "arm64" and override it to "aarch64"
for i in $(seq 1 ${#ARCHS[@]}); do
  if [[ "${ARCHS[$i]}" == "arm64" ]]; then
    ARCHS[$i]="aarch64"
  fi
done

# Get the directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Push to parent directory of scripts folder
pushd "${SCRIPT_DIR}/.." > /dev/null

# Remove previous build and artifacts
rm -rf artifacts/Linux/backend

for ARCH in "${ARCHS[@]}"; do

  # Set build dir if empty
  if [[ -z "${BUILD_DIR}" ]]; then
    BUILD_DIR="build/Linux/backend/${ARCH}"
  fi
  
  rm -rf $BUILD_DIR
  rm -rf eperlium/linux/arch/${ARCH}/

  # Set the toolchain file for cross-compilation
  CMAKE_TOOLCHAIN_FILE=""
  if [ "$ARCH" = "aarch64" ]; then
    CMAKE_TOOLCHAIN_FILE="-DCMAKE_TOOLCHAIN_FILE=$(pwd)/test_repo/cmake/toolchain/linux-arm64.cmake"
  fi

  # Build the project with additional Git SHA and coverage parameters
  cmake \
      -S test_repo \
      -B "${BUILD_DIR}" \
      -Dnetxten_PACKAGING_MAINTAINER_MODE:BOOL=${MAINTAINER_MODE} \
      -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
      -DBUILD_SHARED_LIBS=ON \
      -Dnetxten_ENABLE_COVERAGE:BOOL=${ENABLE_COVERAGE} \
      -DGIT_SHA=${GIT_SHA} \
      $CMAKE_TOOLCHAIN_FILE

  cmake \
      --build "${BUILD_DIR}" \
      --config ${BUILD_TYPE} \
      --verbose

  # Install the project
  mkdir -p artifacts/Linux/backend/${ARCH}
  cmake \
      --install "${BUILD_DIR}" \
      --prefix $(realpath ./artifacts/Linux/backend/${ARCH})

  mkdir -p ./eperlium/linux/arch/${ARCH}
  cp -rf ./artifacts/Linux/backend/${ARCH}/* ./eperlium/linux/arch/${ARCH}/

done

popd > /dev/null