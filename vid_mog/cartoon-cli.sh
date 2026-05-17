#!/usr/bin/env bash

# --------------------------------------------------------
# 1. ENVIRONMENT SETUP & LOCATION AWARENESS
# --------------------------------------------------------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${BASE_DIR}/pyviddy/venv/bin/python3"
CARTOON_SCRIPT="${BASE_DIR}/pyviddy/pyviddy.py"

if [ ! -f "$PYTHON_BIN" ]; then
    echo "❌ Error: Python virtual environment not found at: $PYTHON_BIN"
    echo "Please configure the venv inside the 'pyviddy' folder first."
    exit 1
fi

# --------------------------------------------------------
# 2. HELP SCREEN INTERFACE
# --------------------------------------------------------
show_help() {
    cat << EOF
🎨 AI Model: White-box Cartoonization Wrapper
==================================================
Usage: ./cartoon_cli.sh -i <input.mp4> [options]

Required Arguments:
  -i, --input <path>      Path to the input video file.

Optional Arguments:
  -o, --output <path>     Explicit output file path. 
                          (If omitted, auto-generates a smart path with parameters)

Aesthetic Tuning Options:
  -r, --radius <int>      Filter radius [1-5]. Higher values make flat fields smoother
                          and more painterly. (Default: 1)
  -e, --eps <float>       Epsilon smoothing threshold. Higher values soften details,
                          lower values preserve sharp edges/stars. (Default: 5e-3)
  --intensity <float>     Blending weight [0.0 to 1.0]. 1.0 is full cartoon smoothness,
                          lower blends the raw textured AI back in. (Default: 1.0)

Style Preset Cheat Sheet:
  ✨ Sharp Anime Stars:   -r 1 -e 1e-4
  🌸 Watercolor Nebula:   -r 4 -e 0.05
  🚀 Retro Sci-Fi Book:   -r 5 -e 0.3
  🎨 Gritty Comic Novel:  -r 1 -e 5e-3 --intensity 0.4

System Options:
  -h, --help              Display this help menu.
==================================================
EOF
}

# --------------------------------------------------------
# 3. ARGUMENT PARSING
# --------------------------------------------------------
INPUT=""
OUTPUT=""
RADIUS="1"
EPS="5e-3"
INTENSITY="1.0"

while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--input)
      INPUT="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT="$2"
      shift 2
      ;;
    -r|--radius)
      RADIUS="$2"
      shift 2
      ;;
    -e|--eps)
      EPS="$2"
      shift 2
      ;;
    --intensity)
      INTENSITY="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Run './cartoon_cli.sh --help' to see valid arguments."
      exit 1
      ;;
  esac
done

if [[ -z "$INPUT" ]]; then
    echo "❌ Error: No input file specified."
    echo "Run './cartoon_cli.sh --help' for usage examples."
    exit 1
fi

# --------------------------------------------------------
# 4. PYTHON EXECUTION ARRAY BUILDER
# --------------------------------------------------------
# Using a bash array to cleanly pass arguments without word-splitting issues
CMD_ARGS=(
    "$CARTOON_SCRIPT"
    "--input" "$INPUT"
    "--radius" "$RADIUS"
    "--eps" "$EPS"
    "--intensity" "$INTENSITY"
)

# Only add the output flag if manually specified.
# If omitted, python will automatically generate the smart parameter name!
if [[ -n "$OUTPUT" ]]; then
    CMD_ARGS+=("--output" "$OUTPUT")
fi

echo "🎨 Initializing Neural Networks..."
echo "⚙️ Tuning Parameters: Radius=$RADIUS | Epsilon=$EPS | Intensity=$INTENSITY"

# Call the venv python directly with our arguments array
"$PYTHON_BIN" "${CMD_ARGS[@]}"

if [ $? -eq 0 ]; then
    echo "🚀 Stream complete!"
else
    echo "❌ AI Processing failed. Check hardware/driver compatibility."
    exit 1
fi