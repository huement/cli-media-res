#!/usr/bin/env bash

# 1. Capture arguments
STRING_TO_REMOVE="$1"
TARGET_DIR="${2:-.}" # Defaults to current directory if not provided

# 2. Check for required input
if [[ -z "$STRING_TO_REMOVE" ]]; then
    echo "❌ Error: Missing arguments."
    echo "   Usage:   $0 <string_to_remove> [target_directory]"
    echo "   Example: $0 \"-deep-toon\" \"./output_videos\""
    exit 1
fi

# 3. Verify directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "❌ Error: Directory not found: $TARGET_DIR"
    exit 1
fi

echo "📂 Scanning directory: $TARGET_DIR"
echo "✂️ Removing string: '$STRING_TO_REMOVE'"
echo "-----------------------------------"

# 4. Processing Loop
# Safely handles spaces, brackets, and weird characters in filenames
find "$TARGET_DIR" -maxdepth 1 -type f -name "*${STRING_TO_REMOVE}*" -print0 | while IFS= read -r -d '' file; do
    
    dir_path=$(dirname "$file")
    old_filename=$(basename "$file")
    
    # Native Bash global replacement: substitutes the string with nothing
    new_filename="${old_filename//$STRING_TO_REMOVE/}"
    
    # Reconstruct the full path
    new_file_path="${dir_path}/${new_filename}"
    
    # Perform the rename
    mv "$file" "$new_file_path"
    
    echo "📝 Renamed: $old_filename"
    echo "        -> $new_filename"
    echo ""
done

echo "-----------------------------------"
echo "✅ Done cleaning filenames!"