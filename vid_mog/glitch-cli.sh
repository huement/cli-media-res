#!/usr/bin/env bash

# 1. Source the bash-args library
source "$(dirname "$0")/../bash-args.sh"

# --------------------------------------------------------
# CONFIGURATION & CLI ARGUMENTS
# --------------------------------------------------------
DESCRIPTION="Experimental Databending & Glitch Generator: Translates artistic pipeline code into automated video corruption."

KEYWORDS=(
    "--input|-i;string"
    "--output|-o;string"
    "--mode|-m;string"
    "--gpu;bool"
)

declare -A USAGE
USAGE["--input"]="Input MP4 video file, image file, or folder path."
USAGE["--output"]="Output folder or explicit filename destination."
USAGE["--mode"]="Glitch Engine: 'aberration', 'vectors', 'stack', 'echo', 'databend', or 'morph'." # UPDATED
USAGE["--gpu"]="Enable hardware acceleration (Note: Software encoding is preferred for extreme bit-crushing)."

parse_args "$@" || exit $?

# --------------------------------------------------------
# HELPERS & INITIALIZATION
# --------------------------------------------------------
slugify() {
    echo "$1" | iconv -t ascii//TRANSLIT | sed -E 's/[^a-zA-Z0-9]+/-/g' | sed -E 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]'
}

INPUT_PATH="${KW_ARGS[--input]:-${ARGS[0]:-.}}"
MODE="${KW_ARGS[--mode]:-aberration}"

if [ ! -d "$INPUT_PATH" ] && [ ! -f "$INPUT_PATH" ]; then
    echo "❌ Error: Input target not found: $INPUT_PATH"
    exit 1
fi

if [[ "$INPUT_PATH" == "." ]]; then
    echo "❌ Error: Explicit --input parameter required."
    exit 1
fi

if [ -d "$INPUT_PATH" ]; then
    OUTPUT_DIR="${KW_ARGS[--output]:-$INPUT_PATH}"
else
    OUTPUT_DIR="${KW_ARGS[--output]:-$(dirname "$INPUT_PATH")}"
fi
mkdir -p "$OUTPUT_DIR"

# --------------------------------------------------------
# STREAM EVALUATION LOOP
# --------------------------------------------------------
if [ -f "$INPUT_PATH" ]; then
    printf "%s\0" "$INPUT_PATH"
else
    find "$INPUT_PATH" -maxdepth 1 \( -name "*.mp4" -o -name "*.mov" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -print0
fi | while IFS= read -r -d '' file; do

    filename=$(basename "$file")
    base_name="${filename%.*}"
    ext="${filename##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]'

    # Query internal structural layout parameters
    WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$file" < /dev/null)
    HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$file" < /dev/null)
    [[ -z "$WIDTH" ]] && WIDTH=1280
    [[ -z "$HEIGHT" ]] && HEIGHT=720

    IS_IMAGE=false
    if [[ "$ext_lower" == "png" || "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" ]]; then
        IS_IMAGE=true
    fi

    echo "🎬 Processing: $filename (${WIDTH}x${HEIGHT} | Engine: $MODE)"

    # Base baseline configuration arrays
    FFMPEG_INPUTS=(-i "$file")
    V_ARGS=(-c:v libx264 -pix_fmt yuv420p)
    A_ARGS=(-c:a copy)
    
    if [[ "${KW_ARGS[--gpu]}" == "true" ]]; then
        V_ARGS=(-c:v h264_videotoolbox -pix_fmt yuv420p)
    fi

    # Image-to-Video Loop Patching Step
    if [[ "$IS_IMAGE" == "true" ]]; then
        if [[ "$MODE" == "vectors" || "$MODE" == "stack" || "$MODE" == "echo" || "$MODE" == "morph" ]]; then
            echo "    -> 📸 Static image source detected for temporal effect. Initializing 5s canvas loop..."
            FFMPEG_INPUTS=(-loop 1 -t 5 -i "$file")
        fi
    fi

    # --------------------------------------------------------
    # ENGINE MATRIX SELECTOR
    # --------------------------------------------------------
    case "$MODE" in
        aberration)
            V_FILTER="split=3[r][g][b]; \
                       nullsrc=size=${WIDTH}x${HEIGHT}[b1]; nullsrc=size=${WIDTH}x${HEIGHT}[b2]; nullsrc=size=${WIDTH}x${HEIGHT}[b3]; \
                       [r]lutrgb=g=0:b=0[red]; [g]lutrgb=r=0:b=0[green]; [b]lutrgb=r=0:g=0[blue]; \
                       [b1][red]overlay=x=12:shortest=1,format=rgb24[x]; \
                       [b2][green]overlay=x=0:shortest=1,format=rgb24[y]; \
                       [b3][blue]overlay=y=8:shortest=1,format=rgb24[z]; \
                       [x][y]blend=all_mode='addition'[xy]; \
                       [xy][z]blend=all_mode='addition'[xyz]; \
                       [xyz]crop=${WIDTH}-20:${HEIGHT}-20:10:10,scale=${WIDTH}:${HEIGHT}"
            ;;
            
        vectors)
            FFMPEG_INPUTS=(-flags2 +export_mvs "${FFMPEG_INPUTS[@]}")
            V_FILTER="split[original],codecview=mv=pf+bf+bb[vectors]; \
                       [vectors][original]blend=all_mode=difference128, \
                       eq=contrast=8:brightness=-0.2"
            A_ARGS=(-an)
            ;;
            
        stack)
            V_FILTER="scale=-2:${HEIGHT}, \
                       tblend=all_mode=difference128,tblend=all_mode=difference128,tblend=all_mode=difference128,spp=4:10,tblend=all_mode=average, \
                       tblend=all_mode=difference128,tblend=all_mode=difference128,tblend=all_mode=difference128,spp=4:10,tblend=all_mode=average, \
                       tblend=all_mode=difference128,tblend=all_mode=difference128,tblend=all_mode=difference128"
            ;;
            
        echo)
            if [[ "$IS_IMAGE" == "true" ]]; then
                echo "⚠️  Skipping Echo: Delays require video movement frames."
                continue
            fi
            FFMPEG_INPUTS=(-i "$file" -ss 00:00:00.20 -i "$file" -ss 00:00:00.40 -i "$file")
            V_FILTER="[0][1]blend=all_mode=lighten[a];[1][2]blend=all_mode=lighten[b];[a][b]blend=all_mode=lighten[p];[0][p]blend=all_mode=lighten"
            ;;
            
        databend)
            FFMPEG_INPUTS=(-i "$file" -i "$file" -i "$file")
            V_FILTER="[0][1][2]displace=edge=wrap[middle];[middle]stereo3d=ar"
            V_ARGS=(-c:v libx265 -crf 42 -b:v 15k)
            ;;

        morph) # NEWLY ADDED MODE
            # Advanced Motion-Interpolation Slurring Engine
            echo "    -> 🧠 WARNING: This engine slows footage down 62.5x and renders entirely via CPU threads."
            V_FILTER="setpts=62.5*PTS,minterpolate=fps=25:mb_size=16:search_param=400:vsbmc=0:scd=none:mc_mode=aobmc:me_mode=bilat:me=umh"
            A_ARGS=(-an) # Audio cannot scale down 62.5x smoothly
            ;;
            
        *)
            echo "❌ Error: Engine configuration mode '$MODE' not recognized."
            exit 1
            ;;
    esac

    # Output management
    if [[ "$IS_IMAGE" == "true" && "$MODE" == "aberration" ]]; then
        OUTPUT_NAME="${OUTPUT_DIR}/$(slugify "$base_name")_glitch_${MODE}.png"
        V_ARGS=(-c:v png)
        A_ARGS=()
    else
        OUTPUT_NAME="${OUTPUT_DIR}/$(slugify "$base_name")_glitch_${MODE}.mp4"
    fi

    # --------------------------------------------------------
    # EXECUTE EXPERIMENTAL RENDER PIPELINE
    # --------------------------------------------------------
    if [[ -n "$V_FILTER" ]]; then
        ffmpeg -nostdin -y "${FFMPEG_INPUTS[@]}" \
            -filter_complex "$V_FILTER" \
            "${V_ARGS[@]}" "${A_ARGS[@]}" \
            "$OUTPUT_NAME"
    else
        ffmpeg -nostdin -y "${FFMPEG_INPUTS[@]}" \
            "${V_ARGS[@]}" "${A_ARGS[@]}" \
            "$OUTPUT_NAME"
    fi

    echo "✅ Glitch Complete: $OUTPUT_NAME"
    echo "--------------------------------------------------------"
done