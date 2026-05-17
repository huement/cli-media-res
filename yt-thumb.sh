#!/usr/bin/env bash

# 1. Source the bash-args library (located in the same directory)
source "$(dirname "$0")/bash-args.sh"

# --------------------------------------------------------
# CONFIGURATION & CLI ARGUMENTS
# --------------------------------------------------------
DESCRIPTION="YouTube Thumbnail Generator: Automatically converts images or extracts video frames into a perfectly formatted 1280x720 thumbnail."

KEYWORDS=(
    "--input|-i;string"
    "--output|-o;string"
    "--timecode|-t;string"
)

declare -A USAGE
USAGE["--input"]="Path to the input image file or video file."
USAGE["--output"]="Explicit path for the output JPG. (Default: input_name_yt_thumb.jpg)"
USAGE["--timecode"]="Timecode position to extract frame if input is a video. (Default: 00:00:01)"

parse_args "$@" || exit $?

# --------------------------------------------------------
# INITIALIZATION & ATTRIBUTE PARSING
# --------------------------------------------------------
INPUT_FILE="${KW_ARGS[--input]:-${ARGS[0]}}"
TIMECODE="${KW_ARGS[--timecode]:-00:00:01}"

# Target Spec Validation Check
if [[ -z "$INPUT_FILE" ]]; then
    echo "❌ Error: No input file specified."
    echo "Run './yt-thumb.sh --help' for usage instructions."
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "❌ Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Set up automatic naming structures
FILENAME=$(basename -- "$INPUT_FILE")
FILENAME_NO_EXT="${FILENAME%.*}"
TARGET_DIR=$(dirname -- "$INPUT_FILE")
OUTPUT_FILE="${KW_ARGS[--output]:-${TARGET_DIR}/${FILENAME_NO_EXT}_yt_thumb.jpg}"

TARGET_WIDTH=1280
TARGET_HEIGHT=720
PROCESSING_SRC="$INPUT_FILE"
TEMP_FRAME=""

# Secure temporary file cleanup trap if a video frame is extracted
cleanup() {
    if [[ -n "$TEMP_FRAME" && -f "$TEMP_FRAME" ]]; then
        rm -f "$TEMP_FRAME"
    fi
}
trap cleanup EXIT

# --------------------------------------------------------
# SMART CORE DETECTOR: VIDEO VS IMAGE
# --------------------------------------------------------
echo "🔍 Analyzing format for: $FILENAME..."

# Query ffprobe to see if the input file contains a valid video stream
IS_VIDEO=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE" < /dev/null)

if [[ "$IS_VIDEO" == "video" ]]; then
    echo "🎥 Video detected! Extracting frame at timecode: $TIMECODE..."
    
    # Create a lossless temporary PNG frame file
    TEMP_FRAME=$(mktemp "${TARGET_DIR}/thumb_scratch_XXXXXX.png")
    
    # Fast seek and grab exactly 1 video frame
    ffmpeg -v error -y -ss "$TIMECODE" -i "$INPUT_FILE" -frames:v 1 -q:v 2 "$TEMP_FRAME"
    
    if [ $? -ne 0 ] || [ ! -s "$TEMP_FRAME" ]; then
        echo "❌ Error: FFmpeg failed to extract a frame at '$TIMECODE'. Verify video duration."
        exit 1
    fi
    
    # Redirect ImageMagick's target path to point to our newly extracted frame
    PROCESSING_SRC="$TEMP_FRAME"
else
    echo "📸 Image detected! Passing straight to formatting pipeline..."
fi

# --------------------------------------------------------
# IMAGEMAGICK PROCESSING ENGINE
# --------------------------------------------------------
echo "🎨 Formatting layout to standard YouTube dimensions (${TARGET_WIDTH}x${TARGET_HEIGHT})..."

magick "$PROCESSING_SRC" \
    -resize "${TARGET_WIDTH}x${TARGET_HEIGHT}^" \
    -gravity center \
    -extent "${TARGET_WIDTH}x${TARGET_HEIGHT}" \
    -strip \
    -quality 85 \
    "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "--------------------------------------"
    echo "✨ Success! Created YouTube Thumbnail:"
    echo "📂 Destination: $OUTPUT_FILE"
    echo "📏 Dimensions:  ${TARGET_WIDTH}x${TARGET_HEIGHT} (16:9)"
    echo "⚖️  File Size:   $FILE_SIZE"
    echo "--------------------------------------"
else
    echo "❌ Error: ImageMagick structural rendering pipeline failed."
    exit 1
fi