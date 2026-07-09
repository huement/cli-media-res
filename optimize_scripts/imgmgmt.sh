#!/usr/bin/env bash

# ===================================================
# Image Management, Optimization (imgmgmt.sh)
# ---------------------------------------------------
#
# Description:
#   Processes JPG, JPEG, PNG, and WebP images - single file or directory wide.
#   - Optimizes assets for modern web delivery profiles
#   - Generates responsive thumbnails (200x200 and 500x500)
#   - Converts assets on-the-fly to PNG or WebP formats
#
# Usage:
#   ./imgmgmt.sh <file_or_directory> [--convert-to-png] [--convert-to-webp]
# ===================================================

# Load the ANSI library if present, fallback to basic escaping if not
if [ -f ../ansi ]; then
  source ../ansi
else
  ansi() { echo "$3"; }
fi

# ANSI color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

DIVIDER="${BLUE}==========================================${RESET}"

# ASCII Art Banner
echo -e "${GREEN}"
cat <<"EOF"
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░▀█▀░█▄█░█▀▀░█▄█░█▀▀░█▄█░▀█▀░
░░█░░█░█░█░█░█░█░█░█░█░█░░█░░
░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░░▀░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
EOF
echo -e "${RESET}Image Optimization & Cloud Pipeline - v2.0${RESET}"
echo -e "${BLUE}Starting execution stream...${RESET}"

# Parse command line arguments using a while loop to handle value inputs
CONVERT_TO_PNG=false
CONVERT_TO_WEBP=false

CLI_REMOTE_DIR=""
INPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
  --convert-to-png)
    CONVERT_TO_PNG=true
    echo -e "${YELLOW}➔ PNG transformation context enabled${RESET}"
    shift
    ;;
  --convert-to-webp)
    CONVERT_TO_WEBP=true
    echo -e "${YELLOW}➔ WebP transformation context enabled${RESET}"
    shift
    ;;
  --remote-dir)
    CLI_REMOTE_DIR="$2"
    echo -e "${YELLOW}➔ Custom remote path target: /$CLI_REMOTE_DIR${RESET}"
    shift 2
    ;;
  *)
    if [ -z "$INPUT_PATH" ]; then
      INPUT_PATH="$1"
    fi
    shift
    ;;
  esac
done

# Argument Guard Validation
if [ -z "$INPUT_PATH" ]; then
  echo -e "${RED}Usage: $0 <file_or_directory> [options]${RESET}"
  echo -e "${YELLOW}Options:${RESET}"
  echo -e "  --convert-to-png     Convert input graphics to modern PNG format"
  echo -e "  --convert-to-webp    Convert input graphics to optimized WebP format"
  exit 1
fi

if [ ! -e "$INPUT_PATH" ]; then
  echo -e "${RED}Error: Operational target '$INPUT_PATH' cannot be found.${RESET}"
  exit 1
fi

# Setup Directories
THUMBS_DIR="../temp/thumbs"
mkdir -p "$THUMBS_DIR"

# Core Image Engine Transformations
convert_to_png() {
  local src=$1; local dest=$2
  magick "$src" -quality 95 "$dest"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Formatted PNG build created: $dest${RESET}"
    return 0
  fi
  return 1
}

convert_to_webp() {
  local src=$1; local dest=$2
  magick "$src" -quality 82 "$dest"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Formatted WebP build created: $dest${RESET}"
    return 0
  fi
  return 1
}

resize_image() {
  local src=$1; local dest=$2; local size=$3; local quality=$4
  local width=$(identify -format "%w" "$src")
  local height=$(identify -format "%h" "$src")
  local ratio=$(echo "scale=2; $width / $height" | bc)
  local new_height=$(echo "scale=0; $size / $ratio" | bc)
  
  magick "$src" -resize "${size}x${new_height}^" -gravity center -extent "${size}x${new_height}" -quality "$quality" "$dest"
}

process_image() {
  local file="$1"
  local current="$2"
  local total="$3"

  if [ -n "$total" ]; then
    PERCENT=$(echo "scale=2; ($current * 100) / $total" | bc)
    echo -ne "${YELLOW}Progressing Pipeline: ${PERCENT}% [${current}/${total}]${RESET}\r"
  fi

  echo -e "\n$DIVIDER"
  echo -e "${GREEN}Target Asset Focus: $file${RESET}"

  # Intercept and convert formats before optimization takes place
  if [ "$CONVERT_TO_PNG" = true ] && [[ "$file" =~ \.(jpg|jpeg|webp)$ ]]; then
    local png_file="${file%.*}.png"
    if convert_to_png "$file" "$png_file"; then
      rm "$file" && file="$png_file"
    fi
  elif [ "$CONVERT_TO_WEBP" = true ] && [[ "$file" =~ \.(jpg|jpeg|png)$ ]]; then
    local webp_file="${file%.*}.webp"
    if convert_to_webp "$file" "$webp_file"; then
      rm "$file" && file="$webp_file"
    fi
  elif [[ "$file" =~ \.jpeg$ ]]; then
    local legacy_fix="${file%.jpeg}.jpg"
    mv "$file" "$legacy_fix" && file="$legacy_fix"
  fi

  # Dynamic Extension Parsing for Responsive Resizing Outputs
  local thumb_ext="jpg"
  if [[ "$file" =~ \.png$ ]]; then thumb_ext="png"; fi
  if [[ "$file" =~ \.webp$ ]]; then thumb_ext="webp"; fi

  # Perform Structural Compression and Metadata Striping Blocks
  local filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")

  if [[ "$file" =~ \.jpg$ ]]; then
    local target_q=$([ "$filesize" -gt 102400 ] && echo 75 || echo 60)
    magick "$file" -strip -interlace Plane -quality $target_q "$file"
    echo -e "${BLUE}Optimized JPEG pipeline execution ($target_q% Compression Profile)${RESET}"
  elif [[ "$file" =~ \.png$ ]]; then
    if command -v pngquant &>/dev/null; then
      pngquant --ext .png --force --quality 65-80 "$file" 2>/dev/null
      echo -e "${BLUE}Optimized PNG layout compression stream via pngquant${RESET}"
    else
      magick "$file" -strip -quality 85 "$file"
    fi
  elif [[ "$file" =~ \.webp$ ]]; then
    local target_q=$([ "$filesize" -gt 102400 ] && echo 78 || echo 68)
    magick "$file" -quality $target_q "$file"
    echo -e "${BLUE}Optimized WebP distribution layout ($target_q% Matrix Profile)${RESET}"
  fi

  # Generate Thumbnails if dimensional constraints match criteria
  local dimensions=$(identify -format "%w %h" "$file")
  read -r width height <<< "$dimensions"

  if [ "$width" -gt 500 ]; then
    local q_200=$([ "$filesize" -gt 102400 ] && echo 60 || echo 50)
    local q_500=$([ "$filesize" -gt 102400 ] && echo 80 || echo 70)

    local thumb_200="${THUMBS_DIR}/$(basename "${file%.*}")-200.${thumb_ext}"
    local thumb_500="${THUMBS_DIR}/$(basename "${file%.*}")-500.${thumb_ext}"

    # Build 200px Thumbnail Variant
    if [ ! -f "$thumb_200" ]; then
      resize_image "$file" "$thumb_200" 200 "$q_200"
      echo -e "${BLUE}Generated Thumbnail Grid Matrix ➔ [200px]: $(basename "$thumb_200")${RESET}"
    fi

    # Build 500px Thumbnail Variant
    if [ ! -f "$thumb_500" ]; then
      resize_image "$file" "$thumb_500" 500 "$q_500"
      echo -e "${BLUE}Generated Thumbnail Grid Matrix ➔ [500px]: $(basename "$thumb_500")${RESET}"
    fi
    
  else
    echo -e "${YELLOW}Asset constraints width dimensions below 500px thresholds. Skipping variants.${RESET}"
  fi

}

# Scan Execution Architecture Modes
if [ -f "$INPUT_PATH" ]; then
  echo -e "${GREEN}Target context confirmed ➔ Single Graphic Processing Mode${RESET}"
  process_image "$INPUT_PATH" 1 1
  TOTAL_IMAGES=1
elif [ -d "$INPUT_PATH" ]; then
  echo -e "${GREEN}Target context confirmed ➔ Batch Engine Directory Processing Mode${RESET}"
  
  # Scan filesystem arrays capturing legacy files along with native .webp profiles
  TOTAL_IMAGES=$(find "$INPUT_PATH" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | wc -l)
  CURRENT=0
  
  find "$INPUT_PATH" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | while read -r file; do
    ((CURRENT++))
    process_image "$file" "$CURRENT" "$TOTAL_IMAGES"
  done
fi

echo -e "$DIVIDER"
echo -e "${GREEN}✨ Process complete across total item volume ($TOTAL_IMAGES). All assets localized and synced.${RESET}\n"
exit 0