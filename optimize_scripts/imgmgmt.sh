#!/bin/bash

# ===================================================
# Image Management & Optimization Script (imgmgmt.sh)
# ---------------------------------------------------
#
# Description:
#   This script recursively processes all JPG, JPEG, and PNG images in a given directory.
#   Its a combination of Grok 3 and Whatever AI Cursor uses. Here is what it can do.
#   - Optimizes JPG/JPEG images for web (strips metadata, compresses, renames .jpeg to .jpg)
#   - Optimizes PNG images using pngquant
#   - Generates 200x200 and 500x500 thumbnails for images larger than 200x200 pixels
#   - Skips thumbnail generation for small images
#   - Displays progress and color-coded output for clarity
#   - Saves thumbnails to ./public/images/thumbs
#
# Usage:
#   ./imgmgmt.sh <directory>
#
#   <directory> : Path to the directory containing images to process (recursively)
#
# Requirements:
#   - bash
#   - ImageMagick (convert, identify)
#   - pngquant
#   - ansi (for colored output, see https://github.com/fidian/ansi)
#
# Example:
#   ./imgmgmt.sh ./resources/images
#
# Notes:
#   - The script will create the thumbs directory if it does not exist.
#   - Existing thumbnails are not overwritten.
#   - The script must be run from the directory where the ansi script is located, or adjust the path to ansi accordingly.
# =============================================

# Load the ANSI library
source "/Users/eris/Dotfiles/scripts/_templates/bash-full/library/ansi"  # Adjust path to your ansi installation

# ANSI color variables
RED=$(ansi --red)
GREEN=$(ansi --green)
YELLOW=$(ansi --yellow)
BLUE=$(ansi --blue)
RESET=$(ansi --reset)

# Nice divider
DIVIDER=$(ansi --bold --bg-blue --white "==========================================")

# ASCII Art Banner
echo "${BLUE}"
cat << "EOF"
   ____        _   _   _               _     
  / ___| _   _| |_| |_| |__   ___ _ __| |__  
 | |  _ | | | | __| __| '_ \ / _ \ '__| '_ \ 
 | |_| || |_| | |_| |_| | | |  __/ |  | | | |
  \____| \__,_|\__|\__|_| |_|___|_|  |_| |_| 
                                             
EOF
echo "${RESET}Image Optimization Script - v1.0${RESET}"
echo "${BLUE}Starting at $(date '+%I:%M %p CDT, %B %d, %Y')...${RESET}"

# Check if a directory is provided
if [ -z "$1" ]; then
    echo "${RED}Usage: $0 <directory>${RESET}"
    exit 1
fi

SEARCH_DIR="$1"

# Check if the directory exists
if [ ! -d "$SEARCH_DIR" ]; then
    echo "${RED}Error: Directory '$SEARCH_DIR' not found.${RESET}"
    exit 1
fi

# Check if pngquant is installed
if ! command -v pngquant &> /dev/null; then
    echo "${RED}Error: pngquant is not installed. Please install it first.${RESET}"
    exit 1
fi

# Thumbs directory variable
THUMBS_DIR="./public/images/thumbs"
mkdir -p "$THUMBS_DIR"  # Create thumbs directory if it doesn't exist

# Function to calculate aspect ratio and resize
resize_image() {
    local src=$1
    local dest=$2
    local size=$3
    local quality=$4
    local width=$(identify -format "%w" "$src")
    local height=$(identify -format "%h" "$src")
    local ratio=$(echo "scale=2; $width / $height" | bc)

    if [ "$size" -eq 200 ]; then
        local new_height=$(echo "scale=0; $size / $ratio" | bc)
        convert "$src" -resize "${size}x${new_height}^" -gravity center -extent "${size}x${new_height}" -quality "$quality" "$dest"
    elif [ "$size" -eq 500 ]; then
        local new_height=$(echo "scale=0; $size / $ratio" | bc)
        convert "$src" -resize "${size}x${new_height}^" -gravity center -extent "${size}x${new_height}" -quality "$quality" "$dest"
    fi
}

# Count total images to process
TOTAL_IMAGES=$(find "$SEARCH_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | wc -l)
CURRENT=0
echo "${GREEN}Total images to process: $TOTAL_IMAGES${RESET}"

# Process images
find "$SEARCH_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r file; do
    ((CURRENT++))
    PERCENT=$(echo "scale=2; ($CURRENT * 100) / $TOTAL_IMAGES" | bc)
    echo -ne "${YELLOW}Progress: ${PERCENT}% [${CURRENT}/${TOTAL_IMAGES}]${RESET}\r"

    # Echo filename with divider
    echo ""
    echo "$DIVIDER"
    echo "${GREEN}Processing: $file${RESET}"

    # Rename JPEG to JPG if needed
    if [[ "$file" =~ \.jpeg$ ]]; then
        new_file="${file%.jpeg}.jpg"
        mv "$file" "$new_file"
        file="$new_file"
        echo "${YELLOW}Renamed: $file${RESET}"
    fi

    if [[ "$file" =~ \.jpg$ ]]; then
        # Optimize original image for web (strip metadata, compress)
        filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
        if [ "$filesize" -gt 102400 ]; then  # 100KB in bytes
            convert "$file" -strip -interlace Plane -quality 75 "$file"
            echo "${BLUE}Optimized $file (quality 75%, >100KB)${RESET}"
        else
            convert "$file" -strip -interlace Plane -quality 60 "$file"
            echo "${BLUE}Optimized $file (quality 60%, <=100KB)${RESET}"
        fi

        # Check image dimensions
        dimensions=$(identify -format "%w %h" "$file")
        read width height <<< "$dimensions"
        if [ "$width" -gt 200 ] || [ "$height" -gt 200 ]; then
            # Determine quality based on original file size
            quality_200=$([ "$filesize" -gt 102400 ] && echo 60 || echo 50)
            quality_500=$([ "$filesize" -gt 102400 ] && echo 80 || echo 70)

            # Create 200x200 thumbnail
            thumb_200="${THUMBS_DIR}/${file##*/}-200.jpg"
            if [ ! -f "$thumb_200" ]; then
                echo "${GREEN}-[ 200 ]-${RESET}"
                resize_image "$file" "$thumb_200" 200 "$quality_200"
                echo "${BLUE}Created 200x200 thumbnail: $thumb_200 (quality $quality_200%)${RESET}"
            else
                echo "${YELLOW}200x200 thumbnail already exists: $thumb_200${RESET}"
            fi

            # Create 500x500 thumbnail
            thumb_500="${THUMBS_DIR}/${file##*/}-500.jpg"
            if [ ! -f "$thumb_500" ]; then
                echo "${GREEN}-[ 500 ]-${RESET}"
                resize_image "$file" "$thumb_500" 500 "$quality_500"
                echo "${BLUE}Created 500x500 thumbnail: $thumb_500 (quality $quality_500%)${RESET}"
            else
                echo "${YELLOW}500x500 thumbnail already exists: $thumb_500${RESET}"
            fi
        else
            echo "${YELLOW}Image $file is smaller than 200x200, skipping thumbnails${RESET}"
        fi
    elif [[ "$file" =~ \.png$ ]]; then
        echo "${BLUE}Optimizing PNG with pngquant: $file${RESET}"
        pngquant --ext .png --force --quality 65-80 "$file"
        if [ $? -eq 0 ]; then
            echo "${GREEN}Successfully optimized: $file${RESET}"
        else
            echo "${RED}Failed to optimize: $file${RESET}"
        fi
    fi
done

echo ""
echo "$DIVIDER"
echo "${GREEN}Processing complete! Processed $TOTAL_IMAGES images.${RESET}"
echo "${BLUE}Thumbnails saved in $THUMBS_DIR${RESET}"
echo "$DIVIDER"

exit 0
