#!/bin/zsh

# Zsh script to fix install names and RPATHs for macOS dylibs
# Ensures libraries copied by CMake can find each other when bundled.
# Usage: ./fix_macos_dylibs.zsh <path_to_dylib_directory>

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Consider adding 'set -u' to treat unset variables as errors,
# but ensure all variables like ARTIFACT_LIB_DIR are definitely set.

# --- Argument Handling ---
if [[ $# -ne 1 ]]; then
    echo "Error: Invalid arguments."
    echo "Usage: $0 <path_to_dylib_directory>"
    exit 1
fi

ARTIFACT_LIB_DIR="$1"

# Resolve to absolute path for clarity in logs (optional but good practice)
ARTIFACT_LIB_DIR=$(cd "$ARTIFACT_LIB_DIR"; pwd)

if [[ ! -d "$ARTIFACT_LIB_DIR" ]]; then
    echo "Error: Directory not found: $ARTIFACT_LIB_DIR"
    exit 1
fi
echo "Processing dylibs in: $ARTIFACT_LIB_DIR"

# --- Step 1: Identifying Initial Linkage ---
# Log the state of libraries BEFORE modifications.
echo "\n=== Step 1: Identifying Initial Linkage ==="
# Use Zsh globbing to iterate
for lib in "$ARTIFACT_LIB_DIR"/*.dylib; do
  # Check if the glob matched an actual file
  if [[ -f "$lib" ]]; then
    local lib_basename=$(basename "$lib")
    echo "\n--- Inspecting: $lib_basename ---"
    # Run otool and report errors without exiting (errexit handles critical fails)
    otool -L "$lib" || echo "Warning: otool -L failed on $lib_basename"
    echo "-------------------------------------"
  else
    echo "Warning: Found non-file entry matching *.dylib: $lib"
  fi
done
echo "=== Initial Linkage Inspection Complete ==="


# --- Step 2: Fixing Library Linkage ---
echo "\n=== Step 2: Fixing Library Linkage ==="

# Use Zsh associative array to store original paths found by otool
# Key: basename of the library (e.g., libavformat.58.dylib)
# Value: Full original path string found in otool output
typeset -A original_deps
echo "\n--- Scanning dependencies to identify original paths..."
for lib in "$ARTIFACT_LIB_DIR"/*.dylib; do
    if [[ ! -f "$lib" ]]; then continue; fi
    local lib_basename=$(basename "$lib")

    # Process otool output line by line, skipping the header (first line is self-ref)
    # Use process substitution <(...) to avoid subshell variable scope issues
    while IFS= read -r line; do
        # Extract the path (first word on the line)
        # Zsh parameter expansion for splitting and trimming whitespace
        local dep_path=${${(s: :)line}[1]} # Get first field based on space
        # Optional: More robust trimming if needed: dep_path=${(MS)dep_path##*( )} dep_path=${(MS)dep_path%%*( )}

        # Heuristic: Identify paths likely needing fixing.
        # - Starts with '/' (absolute)
        # - Not a standard system path
        # - Not already an @-path
        if [[ "$dep_path" == /* && "$dep_path" != /System/* && "$dep_path" != /usr/lib/* ]]; then
            local dep_basename=$(basename "$dep_path")
            # Crucially, check if this dependency is one of the libs we actually bundled
            if [[ -f "$ARTIFACT_LIB_DIR/$dep_basename" ]]; then
                # Store the original path string if not already stored for this basename
                if [[ -z "${original_deps[$dep_basename]}" ]]; then
                   original_deps[$dep_basename]="$dep_path"
                   echo "  Identified '$dep_basename' depends on '$dep_path' (will change to @rpath)"
                fi
            fi
        fi
    done < <(otool -L "$lib" | tail -n +2)
done
echo "--- Dependency scan complete. Found ${#original_deps[@]} unique dependencies to potentially fix. ---"

# --- Step 2: Fixing Library Linkage ---
echo "\n=== Step 2: Fixing Library Linkage ==="
echo "\n--- Applying fixes (ID, Dependencies, RPATH)..."

# --- Define library paths ---
# Use variables for easier reading, though paths are hardcoded functionally
LIB_AVDEVICE="$ARTIFACT_LIB_DIR/libavdevice.58.dylib"
LIB_AVFILTER="$ARTIFACT_LIB_DIR/libavfilter.7.dylib"
LIB_AVFORMAT="$ARTIFACT_LIB_DIR/libavformat.58.dylib"
LIB_SWRESAMPLE="$ARTIFACT_LIB_DIR/libswresample.3.dylib"
LIB_SWSCALE="$ARTIFACT_LIB_DIR/libswscale.5.dylib"
# Libs assumed to be mostly okay but needing RPATH:
LIB_ATLAS="$ARTIFACT_LIB_DIR/libatlas_c_sdk.dylib"
LIB_AVCODEC="$ARTIFACT_LIB_DIR/libavcodec.58.dylib"
LIB_AVUTIL="$ARTIFACT_LIB_DIR/libavutil.56.dylib"
LIB_LIVE666="$ARTIFACT_LIB_DIR/liblive666.dylib"

# --- Fix libavdevice.58.dylib ---
echo "\nProcessing $LIB_AVDEVICE..."
install_name_tool -id "@rpath/libavdevice.58.dylib" "$LIB_AVDEVICE"
install_name_tool -change "libavfilter.7.dylib" "@rpath/libavfilter.7.dylib" "$LIB_AVDEVICE"
install_name_tool -change "libswscale.5.dylib" "@rpath/libswscale.5.dylib" "$LIB_AVDEVICE"
install_name_tool -change "libavformat.58.dylib" "@rpath/libavformat.58.dylib" "$LIB_AVDEVICE"
install_name_tool -change "libavcodec.58.dylib" "@rpath/libavcodec.58.dylib" "$LIB_AVDEVICE"
install_name_tool -change "libswresample.3.dylib" "@rpath/libswresample.3.dylib" "$LIB_AVDEVICE"
install_name_tool -change "libavutil.56.dylib" "@rpath/libavutil.56.dylib" "$LIB_AVDEVICE"

# --- Fix libavfilter.7.dylib ---
echo "\nProcessing $LIB_AVFILTER..."
install_name_tool -id "@rpath/libavfilter.7.dylib" "$LIB_AVFILTER"
install_name_tool -change "libswscale.5.dylib" "@rpath/libswscale.5.dylib" "$LIB_AVFILTER"
install_name_tool -change "libavformat.58.dylib" "@rpath/libavformat.58.dylib" "$LIB_AVFILTER"
install_name_tool -change "libavcodec.58.dylib" "@rpath/libavcodec.58.dylib" "$LIB_AVFILTER"
install_name_tool -change "libswresample.3.dylib" "@rpath/libswresample.3.dylib" "$LIB_AVFILTER"
install_name_tool -change "libavutil.56.dylib" "@rpath/libavutil.56.dylib" "$LIB_AVFILTER"

# --- Fix libavformat.58.dylib ---
echo "\nProcessing $LIB_AVFORMAT..."
install_name_tool -id "@rpath/libavformat.58.dylib" "$LIB_AVFORMAT"
install_name_tool -change "libavcodec.58.dylib" "@rpath/libavcodec.58.dylib" "$LIB_AVFORMAT"
install_name_tool -change "libswresample.3.dylib" "@rpath/libswresample.3.dylib" "$LIB_AVFORMAT"
install_name_tool -change "libavutil.56.dylib" "@rpath/libavutil.56.dylib" "$LIB_AVFORMAT"

# --- Fix libswresample.3.dylib ---
# Based on logs, ID might be okay, but dependency needs fixing. Adding ID change for safety.
echo "\nProcessing $LIB_SWRESAMPLE..."
install_name_tool -id "@rpath/libswresample.3.dylib" "$LIB_SWRESAMPLE"
install_name_tool -change "libavutil.56.dylib" "@rpath/libavutil.56.dylib" "$LIB_SWRESAMPLE"

# --- Fix libswscale.5.dylib ---
echo "\nProcessing $LIB_SWSCALE..."
install_name_tool -id "@rpath/libswscale.5.dylib" "$LIB_SWSCALE"
install_name_tool -change "libavutil.56.dylib" "@rpath/libavutil.56.dylib" "$LIB_SWSCALE"

# # --- Add RPATH to ALL bundled libraries ---
# # This ensures that all libraries (even those that already had correct IDs/deps)
# # can resolve the @rpath references by looking in their own directory.
# echo "\nAdding RPATH @loader_path/. to all libraries..."
# for lib in "$ARTIFACT_LIB_DIR"/*.dylib; do
#   if [[ -f "$lib" ]]; then
#     echo "  Adding RPATH to $(basename "$lib")"
#     # Add unconditionally; duplicates are usually ignored or harmless. Remove check for simplicity.
#     install_name_tool -add_rpath "@loader_path/." "$lib" || echo "Warning: Failed to add RPATH to $(basename "$lib") (might already exist or other issue)"
#   fi
# done

echo "\nHardcoded dylib fixing complete."

# --- Step 3: Verifying Fixed Linkage ---
# Log the state of libraries AFTER modifications.
echo "\n=== Step 3: Verifying Fixed Linkage ==="
for lib in "$ARTIFACT_LIB_DIR"/*.dylib; do
  if [[ -f "$lib" ]]; then
    local lib_basename=$(basename "$lib")
    echo "\n--- Verifying: $lib_basename ---"
    otool -L "$lib" || echo "Warning: otool -L failed on $lib_basename"
    # otool -l "$lib" | grep LC_RPATH -A 3 # Show RPATH entries specifically
    echo "-------------------------------------"
  fi
done
echo "=== Verification Complete ==="


echo "\n Dylib processing finished successfully for directory: $ARTIFACT_LIB_DIR"
exit 0