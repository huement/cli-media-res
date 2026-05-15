#!/bin/bash

# Script to optimize JPEG files in a directory for web use and rename them
# Usage: ./optimize_jpgs.sh [directory] [prefix]
# - directory: Path to directory with JPEGs (defaults to script's directory)
# - prefix: Custom prefix for output files (defaults to 'webphoto')

# Ensure the ansi binary is in the same directory as the script
ANSI_BINARY="/Users/eris/Dotfiles/scripts/_templates/bash-full/library/ansi"
if [[ ! -f "$ANSI_BINARY" || ! -x "$ANSI_BINARY" ]]; then
    echo "Error: 'ansi' binary not found or not executable in $(dirname "$0")"
    exit 1
fi

# Function to print colored messages using ansi
print_msg() {
    local type="$1"
    local msg="$2"
    case "$type" in
        "info") "$ANSI_BINARY" --green "$msg" ;;
        "error") "$ANSI_BINARY" --red "$msg" ;;
        "success") "$ANSI_BINARY" --cyan "$msg" ;;
        "header") "$ANSI_BINARY" --bold --underline "$msg" ;;
    esac
}

# Check if ImageMagick is installed, install via Homebrew if not
check_imagemagick() {
    if ! command -v convert >/dev/null 2>&1; then
        print_msg "error" "ImageMagick not found. Installing via Homebrew..."
        if ! command -v brew >/dev/null 2>&1; then
            print_msg "error" "Homebrew not installed. Please install Homebrew first: https://brew.sh"
            exit 1
        fi
        brew install imagemagick
        if [[ $? -ne 0 ]]; then
            print_msg "error" "Failed to install ImageMagick. Please install it manually."
            exit 1
        fi
        print_msg "success" "ImageMagick installed successfully."
    else
        print_msg "info" "ImageMagick is already installed."
    fi
}

# Set directory (first argument or script's directory)
DIR="${1:-$(dirname "$0")}"
if [[ ! -d "$DIR" ]]; then
    print_msg "error" "Directory '$DIR' does not exist."
    exit 1
fi
# Convert to absolute path
DIR=$(realpath "$DIR")

# Set prefix (second argument or default to 'webphoto')
PREFIX="${2:-webphoto}"

# Create output directory for optimized files
OUTPUT_DIR="$DIR/optimized"
mkdir -p "$OUTPUT_DIR"
if [[ $? -ne 0 ]]; then
    print_msg "error" "Failed to create output directory '$OUTPUT_DIR'."
    exit 1
fi

# Print header
print_msg "header" "Optimizing JPEG files in '$DIR' with prefix '$PREFIX'"

# Check for ImageMagick
check_imagemagick

# Counter for naming files
COUNTER=0

# Find all JPEG files (case-insensitive) and process them
find "$DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | while read -r FILE; do
    # Skip files already in the optimized directory
    if [[ "$FILE" == "$OUTPUT_DIR/"* ]]; then
        continue
    fi

    BASENAME=$(basename "$FILE")
    OUTPUT_FILE="$OUTPUT_DIR/${PREFIX}-${COUNTER}.jpg"

    print_msg "info" "Processing '$BASENAME' -> '${PREFIX}-${COUNTER}.jpg'"

    # Optimize and resize using ImageMagick
    magick "$FILE" -resize 1440x\> -quality 85 -strip "$OUTPUT_FILE"
    if [[ $? -eq 0 ]]; then
        print_msg "success" "Optimized '$BASENAME' to '$OUTPUT_FILE'"
        (( COUNTER++ ))
    else
        print_msg "error" "Failed to optimize '$BASENAME'"
    fi
done

# Check if any files were processed
if [[ $COUNTER -eq 1 ]]; then
    print_msg "error" "No JPEG files found in '$DIR'."
else
    print_msg "success" "Optimization complete. Files saved in '$OUTPUT_DIR'."
fi