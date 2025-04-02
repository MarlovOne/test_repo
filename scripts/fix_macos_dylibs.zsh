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


echo "\n--- Applying fixes (ID, Dependencies, RPATH)..."
# Now iterate again to apply the changes using the stored original paths
for lib in "$ARTIFACT_LIB_DIR"/*.dylib; do
  if [[ ! -f "$lib" ]]; then continue; fi
  local lib_basename=$(basename "$lib")
  echo "\nProcessing File: $lib_basename"

  # 1. Fix the library's own Install Name (ID) to be @rpath relative
  echo "  Setting ID -> @rpath/$lib_basename"
  install_name_tool -id "@rpath/$lib_basename" "$lib"

  # 2. Fix dependencies pointing to *other* bundled libraries
  # Rerun otool to get current list as dependencies might change during the loop
  while IFS= read -r line; do
      local current_dep_path=${${(s: :)line}[1]}
      local dep_basename=$(basename "$current_dep_path")

      # Check if this basename exists in our stored original paths map
      # Zsh check for key existence: ${(k)original_deps[(i)$dep_basename]} <= ${#original_deps}
      if [[ -v original_deps[$dep_basename] ]]; then
          local original_path_to_change=${original_deps[$dep_basename]}
          local target_path="@rpath/$dep_basename"

          # IMPORTANT: Only run -change if the current path *exactly matches* the stored original path
          # Avoids errors if a path was already changed by fixing another library that depends on this one.
          if [[ "$current_dep_path" == "$original_path_to_change" ]]; then
              echo "  Changing Dep: '$original_path_to_change' -> '$target_path'"
              install_name_tool -change "$original_path_to_change" "$target_path" "$lib"
          elif [[ "$current_dep_path" == "$target_path" ]]; then
              # Already fixed, likely due to another lib's fix propagating. This is fine.
              echo "  Dep OK: '$current_dep_path' (already fixed)"
          else
              # Path doesn't match original OR target - could be a system lib or unexpected state.
              # Log this for investigation if needed, but don't try to change it based on current logic.
              # echo "  Skipping Dep: '$current_dep_path' (doesn't match original '$original_path_to_change')"
              : # No-op, dependency doesn't match what we expected to change
          fi
      fi
  done < <(otool -L "$lib" | tail -n +2)

  # 3. Add RPATH for inter-library searching (@loader_path/. means "look in my own directory")
  # Check if this specific RPATH already exists to prevent duplicates
  if ! otool -l "$lib" | grep -A 2 LC_RPATH | grep -q -F "@loader_path/."; then
     echo "  Adding RPATH -> @loader_path/."
     install_name_tool -add_rpath "@loader_path/." "$lib"
  else
     echo "  RPATH OK: '@loader_path/.' already exists."
  fi
  echo "-------------------------------------"
done
echo "=== Linkage Fixing Complete ==="


# --- Step 3: Verifying Fixed Linkage ---
# Log the state of libraries AFTER modifications.
echo "\n=== Step 3: Verifying Fixed Linkage ==="
for lib in "$ARTIFACT_LIB_DIR"/*.dylib; do
  if [[ -f "$lib" ]]; then
    local lib_basename=$(basename "$lib")
    echo "\n--- Verifying: $lib_basename ---"
    otool -L "$lib" || echo "Warning: otool -L failed on $lib_basename"
    otool -l "$lib" | grep LC_RPATH -A 3 # Show RPATH entries specifically
    echo "-------------------------------------"
  fi
done
echo "=== Verification Complete ==="


echo "\n Dylib processing finished successfully for directory: $ARTIFACT_LIB_DIR"
exit 0