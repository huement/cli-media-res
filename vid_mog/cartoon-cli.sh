#!/usr/bin/env bash

# --------------------------------------------------------
# 1. ENVIRONMENT SETUP & LOCATION AWARENESS
# --------------------------------------------------------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${BASE_DIR}/pyviddy/venv/bin/python3"
CARTOON_SCRIPT="${BASE_DIR}/pyviddy/cartoonize.py"

# --------------------------------------------------------
# 2. HELP SCREEN INTERFACE
# --------------------------------------------------------
show_help() {
    cat << EOF
🎨 Mega Cartoonization Toolkit (AI, FFmpeg, & Shaders)
==================================================
Usage: ./cartoon_cli.sh -i <input.mp4> -m <mode> [options]

Required Arguments:
  -i, --input <path>      Path to the input video file.

Engine Selection:
  -m, --mode <engine>     Processing engine to use:
                            'ai'      -> White-box Neural Network (Default)
                            'recipe'  -> FFmpeg Bilateral + Canny Edge
                            'frei0r'  -> Frei0r Cartoon Plugin
                            'shader'  -> GPU GLSL Shader via MPV

Optional Arguments:
  -o, --output <path>     Explicit output file path. 
                          (If omitted, auto-generates a smart path based on mode)
  -s, --shader <path>     Path to .glsl shader file (Required if mode is 'shader')

AI Mode Tuning Options (Only applies to -m ai):
  -r, --radius <int>      Filter radius [1-5]. (Default: 1)
  -e, --eps <float>       Epsilon smoothing threshold. (Default: 5e-3)
  --intensity <float>     Blending weight [0.0 to 1.0]. (Default: 1.0)
  
Style Preset Cheat Sheet:
✨ Sharp Anime Stars:   -r 1 -e 1e-4
🌸 Watercolor Nebula:   -r 4 -e 0.05
🚀 Retro Sci-Fi Book:   -r 5 -e 0.3
🎨 Gritty Comic Novel:  -r 1 -e 5e-3 --intensity 0.4

==================================================
EOF
}

# --------------------------------------------------------
# 3. ARGUMENT PARSING & DEFAULTS
# --------------------------------------------------------
INPUT=""
OUTPUT=""
MODE="ai"
SHADER=""
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
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -s|--shader)
      SHADER="$2"
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

# Basic Validation
if [[ -z "$INPUT" ]]; then
    echo "❌ Error: No input file specified."
    exit 1
fi

if [[ ! -f "$INPUT" ]]; then
    echo "❌ Error: Input file does not exist: $INPUT"
    exit 1
fi

# Smart Auto-Naming for FFmpeg/MPV modes if output is omitted
if [[ -z "$OUTPUT" ]]; then
    filename=$(basename -- "$INPUT")
    extension="${filename##*.}"
    filename="${filename%.*}"
    OUTPUT="${filename}_${MODE}.${extension}"
fi

# --------------------------------------------------------
# 4. EXECUTION ROUTER
# --------------------------------------------------------
case $MODE in

  ai)
    if [ ! -f "$PYTHON_BIN" ]; then
        echo "❌ Error: Python virtual environment not found at: $PYTHON_BIN"
        exit 1
    fi
    
    CMD_ARGS=(
        "$CARTOON_SCRIPT"
        "--input" "$INPUT"
        "--radius" "$RADIUS"
        "--eps" "$EPS"
        "--intensity" "$INTENSITY"
    )
    # If the user explicitly defined an output, pass it to Python. 
    # Otherwise, clear OUTPUT so your Python script auto-generates its smart name.
    if [[ "$OUTPUT" != *_${MODE}.* ]]; then
        CMD_ARGS+=("--output" "$OUTPUT")
    fi

    echo "🎨 Engine: Neural Networks (White-Box)..."
    "$PYTHON_BIN" "${CMD_ARGS[@]}"
    ;;
	
  recipe)
    echo "🧪 Engine: FFmpeg Fixed Recipe (RGB-Isolated Bilateral + Posterise + Edge Detect)..."
    ffmpeg -i "$INPUT" -filter_complex \
    "[0:v]bilateral=sigmaS=10:sigmaR=0.2,eq=saturation=1.5,lutrgb=r='val-mod(val,64)':g='val-mod(val,64)':b='val-mod(val,64)',format=rgb24[flat]; \
     [0:v]edgedetect=low=0.06:high=0.12,negate,format=rgb24[lines]; \
     [flat][lines]blend=all_mode=multiply,format=rgb24[blended]; \
     [blended]format=yuv420p[out]" \
    -map "[out]" -c:a copy -y "$OUTPUT"
    ;;

  frei0r)
    echo "🔌 Engine: FFmpeg Frei0r Plugin..."
    # Verify plugin presence first
    if ! ffmpeg -filters 2>&1 | grep -q frei0r; then
        echo "❌ Error: Your FFmpeg build does not support Frei0r filters."
        exit 1
    fi
	
	# Mandate the path directly inside the script execution environment
    if [ -d "/usr/local/lib/frei0r-1" ]; then
        export FREI0R_PATH="/usr/local/lib/frei0r-1"
    elif [ -d "/opt/homebrew/lib/frei0r-1" ]; then
        export FREI0R_PATH="/opt/homebrew/lib/frei0r-1"
    fi
	
    ffmpeg -i "$INPUT" -vf "frei0r=filter_name=cartoon" -c:a copy -y "$OUTPUT"
    ;;

  shader)
    echo "🎮 Engine: GPU GLSL Shader Pipeline..."
    if [[ -z "$SHADER" ]]; then
        echo "❌ Error: Mode 'shader' requires a shader path via -s or --shader"
        exit 1
    fi
    if [ ! -f "$SHADER" ]; then
        echo "❌ Error: Shader file not found at: $SHADER"
        exit 1
    fi
    if ! command -v mpv &> /dev/null; then
        echo "❌ Error: 'mpv' media player is required to render GLSL shaders."
        echo "Install it via Homebrew: brew install mpv"
        exit 1
    fi
    
    mpv "$INPUT" --glsl-shaders="$SHADER" -o "$OUTPUT"
    ;;

  *)
    echo "❌ Error: Invalid mode '$MODE'. Choose from: ai, recipe, frei0r, shader."
    exit 1
    ;;
esac

# --------------------------------------------------------
# 5. POST-FLIGHT CHECK
# --------------------------------------------------------
if [ $? -eq 0 ]; then
    echo "🚀 Stream complete! Output saved to: $OUTPUT"
else
    echo "❌ Processing failed. Check your configuration or parameters."
    exit 1
fi