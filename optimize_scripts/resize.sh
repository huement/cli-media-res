#!/bin/bash

# 1. Choose the folder (Defaults to current directory if you don't provide one)
TARGET_DIR="${1:-.}"

# 2. Check for ImageMagick (handles 'magick' or 'convert' for older versions)
if command -v magick &> /dev/null; then
    CMD="magick"
elif command -v convert &> /dev/null; then
    CMD="convert"
else
    echo "Error: ImageMagick not found. Please install it."
    exit 1
fi

echo "Processing images in: $TARGET_DIR"

# 3. Use 'find' to locate images and process them
# This handles subfolders and avoids "file not found" errors
find "$TARGET_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | while read -r img; do
    
    # Skip files that we already resized (prevents an infinite loop)
    if [[ "$img" == *"_resized"* ]]; then
        continue
    fi

    # Create the new filename (e.g., photo.jpg -> photo_resized.jpg)
    extension="${img##*.}"
    filename="${img%.*}"
    output="${filename}_resized.${extension}"

    echo "Resizing: $img"
    
    # Resize: 1920 width, auto height, only shrink if larger (>)
    $CMD "$img" -resize '1920x>' "$output"
done

echo "Done! Look for files ending in '_resized' in $TARGET_DIR"
