#!/bin/bash

# Check if an image path was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <image_path>"
    exit 1
fi

# Check if the file exists
if [ ! -f "$1" ]; then
    echo "Error: File '$1' not found"
    exit 1
fi

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is required. Please install it."
    exit 1
fi

# Get the input file path and directory
input_file="$1"
filename=$(basename "$input_file")
extension="${filename##*.}"
filename_noext="${filename%.*}"
directory=$(dirname "$input_file")

# Output thumbnail path
output_file="${directory}/${filename_noext}_thumb.jpg"

# Get original dimensions
dimensions=$(identify -format "%w %h" "$input_file" 2>/dev/null)
read width height <<< "$dimensions"

# Check if image identification was successful
if [ $? -ne 0 ]; then
    echo "Error: Unable to process image '$input_file'"
    exit 1
fi

# If image is smaller than 500x500, copy it with compression only
if [ $width -le 500 ] && [ $height -le 500 ]; then
    convert "$input_file" \
        -strip \
        -interlace Plane \
        -quality 85 \
        "$output_file"
else
    # Resize and compress
    convert "$input_file" \
        -resize 500x500\> \
        -strip \
        -interlace Plane \
        -quality 85 \
        -sampling-factor 4:2:0 \
        -colorspace sRGB \
        "$output_file"
fi

# Check if conversion was successful
if [ $? -eq 0 ]; then
    echo "Thumbnail created: $output_file"
else
    echo "Error: Failed to create thumbnail"
    exit 1
fi
