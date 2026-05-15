#!/bin/bash

# Check if an input file was provided
if [ -z "$1" ]; then
    echo "Usage: ./yt-thumb.sh <image_file>"
    exit 1
fi

INPUT_FILE="$1"
FILENAME=$(basename -- "$INPUT_FILE")
EXTENSION="${FILENAME##*.}"
FILENAME_NO_EXT="${FILENAME%.*}"
OUTPUT_FILE="${FILENAME_NO_EXT}_yt_thumb.jpg"

# YouTube Specs: 1280x720 (16:9), Max 2MB, JPG/PNG
TARGET_WIDTH=1280
TARGET_HEIGHT=720

echo "Processing $INPUT_FILE..."

# ImageMagick Magic:
# 1. -resize: Fills the 1280x720 box (the ^ ensures the smaller dimension matches)
# 2. -gravity center: Centers the crop point
# 3. -extent: Crops the image to exactly 1280x720
# 4. -strip: Removes metadata (GPS, camera info) to save space
# 5. -quality: Set to 85% for high visual quality but small file size
magick "$INPUT_FILE" \
    -resize "${TARGET_WIDTH}x${TARGET_HEIGHT}^" \
    -gravity center \
    -extent "${TARGET_WIDTH}x${TARGET_HEIGHT}" \
    -strip \
    -quality 85 \
    "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "--------------------------------------"
    echo "Success! Created: $OUTPUT_FILE"
    echo "Dimensions: ${TARGET_WIDTH}x${TARGET_HEIGHT}"
    echo "Final File Size: $FILE_SIZE"
    echo "--------------------------------------"
else
    echo "Error: Something went wrong during processing."
fi