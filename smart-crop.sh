#!/bin/bash

# 1. Capture the parameters
WIDTH=$1
HEIGHT=$2
TARGET_DIR=$3

# 2. Check if all parameters are provided
if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ] || [ -z "$TARGET_DIR" ]; then
    echo "Usage: ./smart_crop.sh [width] [height] [directory]"
    echo "Example: ./smart_crop.sh 1920 1080 ./my_images"
    exit 1
fi

# 3. Check for ImageMagick
if command -v magick &> /dev/null; then
    CMD="magick"
elif command -v convert &> /dev/null; then
    CMD="convert"
else
    echo "Error: ImageMagick is not installed."
    exit 1
fi

# 4. Create an output folder inside the target directory
OUTPUT_DIR="$TARGET_DIR/cropped_${WIDTH}x${HEIGHT}"
mkdir -p "$OUTPUT_DIR"

echo "Cropping images in $TARGET_DIR to ${WIDTH}x${HEIGHT}..."

# 5. Process the images
# We use -resize "WxH^" to fill the area, then -extent to crop from center
find "$TARGET_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | while read -r img; do
    
    # Get just the filename (e.g., photo.jpg) without the path
    filename=$(basename "$img")
    
    echo "Processing: $filename"

    # The Logic:
    # -resize "${WIDTH}x${HEIGHT}^"  -> Resize so the SMALLER side matches, filling the box
    # -gravity center               -> Set the focus to the middle
    # -extent "${WIDTH}x${HEIGHT}"   -> Cut off everything outside the box
    $CMD "$img" -resize "${WIDTH}x${HEIGHT}^" -gravity center -extent "${WIDTH}x${HEIGHT}" "$OUTPUT_DIR/$filename"

done

echo "---"
echo "Done! Your cropped images are in: $OUTPUT_DIR"
