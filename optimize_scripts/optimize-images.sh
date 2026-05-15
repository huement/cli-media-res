#!/bin/bash

# Script to optimize ALL IMAGE files (PNG & JPG) in a directory for web use
# Usage: ./optimize_images.sh [directory]
# - directory: Path to directory with PNGS/JPEGs (defaults to script's directory)

# Ensure the ansi binary is in the same directory as the script
ANSI_BINARY="/Users/eris/Dotfiles/scripts/_templates/bash-full/library/ansi"
if [[ ! -f "$ANSI_BINARY" || ! -x "$ANSI_BINARY" ]]; then
    print_msg "error" "Error: 'ansi' binary not found or not executable in $(dirname "$0")"
    exit 1
fi

# ANSI color variables
NORMAL="$(tput sgr0)" # Text Reset
NC="$(tput sgr0)" # Text Reset
BOLD="$(tput bold)" # Make Bold
UNDERLINE="$(tput smul)" # Underline
NOUNDER="$(tput rmul)" # Remove Underline
BLINK="$(tput blink)" # Make Blink
REVERSE="$(tput rev)" # Reverse
BLACK="$(tput setaf 0)" # Black
RED="$(tput setaf 1)" # Red
GREEN="$(tput setaf 2)" # Green
YELLOW="$(tput setaf 3)" # Yellow
BLUE="$(tput setaf 4)" # Blue
PURPLE="$(tput setaf 5)" # Purple
CYAN="$(tput setaf 6)" # Cyan
WHITE="$(tput setaf 7)" # White

# Check if a directory is provided
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <directory>${RESET}"
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

# Check if required tools are installed, install via Homebrew if not
check_tools() {
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

    if ! command -v optipng >/dev/null 2>&1; then
        print_msg "error" "optipng not found. Installing via Homebrew..."
        brew install optipng
        if [[ $? -ne 0 ]]; then
            print_msg "error" "Failed to install optipng. Please install it manually."
            exit 1
        fi
        print_msg "success" "optipng installed successfully."
    else
        print_msg "info" "optipng is already installed."
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

# Create output directory for optimized files
OUTPUT_DIR="$DIR/optimized"
mkdir -p "$OUTPUT_DIR"
if [[ $? -ne 0 ]]; then
    print_msg "error" "Failed to create output directory '$OUTPUT_DIR'."
    exit 1
fi

# Print header
print_msg "header" "Optimizing IMAGE files in '$DIR'"

# Check for required tools
check_tools

# Counter for tracking processed files
COUNTER=0

# Thumbs directory variable
THUMBS_DIR="$DIR/thumbs"
mkdir -p "$THUMBS_DIR"  # Create thumbs directory if it doesn't exist

# Find all JPEG and PNG files (case-insensitive) and process them
find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r FILE; do
    # Skip files already in the optimized directory
    if [[ "$FILE" == "$OUTPUT_DIR/"* ]]; then
        continue
    fi

    BASENAME=$(basename "$FILE")
    OUTPUT_FILE="$OUTPUT_DIR/$BASENAME"

    print_msg "info" "Processing '$BASENAME' -> '$OUTPUT_FILE'"

	COUNTER=$COUNTER+1
	
    case "${FILE##*.}" in
        "jpg"|"jpeg")
            # Rename JPEG to JPG if needed
            if [[ "$FILE" =~ \.jpeg$ ]]; then
                new_file="${FILE%.jpeg}.jpg"
                mv "$FILE" "$new_file"
                FILE="$new_file"
				BASENAME=$(basename "$FILE")
				OUTPUT_FILE="$OUTPUT_DIR/$BASENAME"
				echo "${YELLOW}REEnamed jpeg to jpg: ${BASENAME}${RESET}"
            fi

            # Optimize JPEG using ImageMagick
            magick "$FILE" -quality 75 -interlace Plane -strip "$OUTPUT_FILE"
            if [[ $? -eq 0 ]]; then
                print_msg "success" "Optimized '$BASENAME' to '$OUTPUT_FILE'"
                ((COUNTER++))
            else
                print_msg "error" "Failed to optimize '$BASENAME'"
            fi

            # Create 500x500 thumbnail
            thumb_500="${THUMBS_DIR}/${BASENAME%.*}-500.jpg"
            if [ ! -f "$thumb_500" ]; then
                echo "${GREEN}-[ 500 ]-${RESET}"
                magick "$FILE" -resize 500x500^ -gravity center -extent 500x500 -quality 80 "$thumb_500"
                if [[ $? -eq 0 ]]; then
                    echo "${BLUE}Created 500x500 thumbnail: $thumb_500${RESET}"
                else
                    echo "${RED}Failed to create thumbnail: $thumb_500${RESET}"
                fi
            else
                echo "${YELLOW}500x500 thumbnail already exists: $thumb_500${RESET}"
            fi

             ((COUNTER++))
            ;;
        "png")
            # Optimize PNG using optipng
            optipng -o7 "$FILE" -out "$OUTPUT_FILE"
            if [[ $? -eq 0 ]]; then
                print_msg "success" "Optimized '$BASENAME' to '$OUTPUT_FILE'"
            else
                print_msg "error" "Failed to optimize '$BASENAME'"
            fi

            # Create 500x500 thumbnail
            thumb_500="${THUMBS_DIR}/${BASENAME%.*}-500.jpg"
            if [ ! -f "$thumb_500" ]; then
                echo "${GREEN}-[ 500 ]-${RESET}"
                magick "$FILE" -resize 500x500^ -gravity center -extent 500x500 -quality 80 "$thumb_500"
                if [[ $? -eq 0 ]]; then
                    echo "${BLUE}Created 500x500 thumbnail: $thumb_500${RESET}"
                else
                    echo "${RED}Failed to create thumbnail: $thumb_500${RESET}"
                fi
            else
                echo "${YELLOW}500x500 thumbnail already exists: $thumb_500${RESET}"
            fi


            ((COUNTER++))
            ;;
        *)
            print_msg "error" "Unsupported file type for '$BASENAME'"
            ;;
    esac
done

# Check if any files were processed
if [[ $COUNTER -eq 0 ]]; then
    print_msg "error" "No image files found in '$DIR'."
else
    print_msg "success" "Optimization complete. $COUNTER files saved in '$OUTPUT_DIR'."
fi
