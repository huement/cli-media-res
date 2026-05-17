#!/usr/bin/env bash

# --------------------------------------------------------
# 1. ENVIRONMENT SETUP & LOCATION AWARENESS
# --------------------------------------------------------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${BASE_DIR}/pyviddy/venv/bin/python3"
LOOPER_SCRIPT="${BASE_DIR}/pyviddy/looper.py"

if [ ! -f "$PYTHON_BIN" ]; then
    echo "❌ Error: Python virtual environment not found at: $PYTHON_BIN"
    echo "Please configure the venv inside the 'pyviddy' folder first."
    exit 1
fi

if [ ! -f "$LOOPER_SCRIPT" ]; then
    echo "❌ Error: Looper script not found at: $LOOPER_SCRIPT"
    exit 1
fi

# --------------------------------------------------------
# 2. HELP SCREEN INTERFACE
# --------------------------------------------------------
show_help() {
    cat << EOF
🔁 Video Looper Utility Wrapper
==================================================
Usage: ./loop_cli.sh -i <input.mp4> [options]

Required Arguments:
  -i, --input <path>      Path to the input video file.

Loop Configuration:
  -m, --mode <type>       Type of loop to generate: 'repeat' or 'boomerang'.
                          (Default: repeat)
  -c, --count <int>       Number of times to play back the clip. 
                          Only applies to 'repeat' mode. (Default: 3)

Output Adjustments:
  -d, --outdir <path>     Manually set a target directory for the output video.
                          (If omitted, defaults to the input file's directory)

Hardware Acceleration:
  --gpu                   Enable GPU NVENC hardware acceleration.

System Options:
  -h, --help              Display this help menu.
==================================================
EOF
}

# --------------------------------------------------------
# 3. ARGUMENT PARSING
# --------------------------------------------------------
INPUT=""
OUT_DIR=""
MODE="repeat"
COUNT="3"
GPU="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--input)
      INPUT="$2"
      shift 2
      ;;
    -d|--outdir)
      OUT_DIR="$2"
      shift 2
      ;;
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -c|--count)
      COUNT="$2"
      shift 2
      ;;
    --gpu)
      GPU="true"
      shift 1
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Run './loop_cli.sh --help' to see valid arguments."
      exit 1
      ;;
  esac
done

# Validation
if [[ -z "$INPUT" ]]; then
    echo "❌ Error: No input file specified."
    echo "Run './loop_cli.sh --help' for usage examples."
    exit 1
fi

if [[ "$MODE" != "repeat" && "$MODE" != "boomerang" ]]; then
    echo "❌ Error: Invalid mode '$MODE'. Choose 'repeat' or 'boomerang'."
    exit 1
fi

# --------------------------------------------------------
# 4. PATH ROUTING LOGIC & FILENAME MANIPULATION
# --------------------------------------------------------
# Extract base elements cleanly
FILENAME=$(basename -- "$INPUT")
EXT="${FILENAME##*.}"
NAME="${FILENAME%.*}"

# Determine target directory and enforce "_looped" suffix rule
if [[ -n "$OUT_DIR" ]]; then
    # Ensure target directory exists before running
    mkdir -p "$OUT_DIR"
    OUTPUT_PATH="${OUT_DIR}/${NAME}_looped.${EXT}"
else
    TARGET_DIR=$(dirname -- "$INPUT")
    OUTPUT_PATH="${TARGET_DIR}/${NAME}_looped.${EXT}"
fi

# --------------------------------------------------------
# 5. PYTHON EXECUTION ARRAY BUILDER
# --------------------------------------------------------
CMD_ARGS=(
    "$LOOPER_SCRIPT"
    "--input" "$INPUT"
    "--output" "$OUTPUT_PATH"
    "--mode" "$MODE"
    "--count" "$COUNT"
)

# Conditionally append GPU flag toggle if requested
if [[ "$GPU" == "true" ]]; then
    CMD_ARGS+=("--gpu")
fi

echo "🔁 Initializing Video Looper Processing..."
echo "⚙️ Tuning Parameters: Mode=$MODE | Count=$COUNT | Target=$OUTPUT_PATH"

# Run the python execution via the localized environment binary
"$PYTHON_BIN" "${CMD_ARGS[@]}"

if [ $? -eq 0 ]; then
    echo "🚀 Loop generation complete!"
else
    echo "❌ Looping sequence engine failed. Verify input file permissions/formats."
    exit 1
fi