#!/usr/bin/env bash

# 1. Source the bash-args library
source "$(dirname "$0")/../bash-args.sh"

# --------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------
DESCRIPTION="Space & Starfield Optimizer: Sequential filter processing."

KEYWORDS=(
    "--input|-i;string"
    "--output|-o;string"
    "--bloom;bool"
    "--twinkle;bool"
    "--aberration;bool"
    "--cartoon;bool"
    "--crush;bool"
    "--grain;bool"
    "--glitch;bool"
    "--lut|-l;string"
    "--watermark|-wm;string"
    "--wm-width|-ww;int"
    "--bitrate|-b;string"
)

declare -A USAGE
USAGE["--input"]="Input folder containing mp4 files or a path to a single mp4 file."
USAGE["--output"]="Output folder for processed files."
USAGE["--lut"]="Path to the .cube LUT file."
USAGE["--grain"]="Enable film grain effect."
USAGE["--glitch"]="Enable anaglyphic RGB shift glitch effect."
USAGE["--watermark"]="Path to the watermark image."
USAGE["--wm-width"]="Width of the watermark (Default: 120)."
USAGE["--bitrate"]="Video bitrate (Default: 15000k)."

parse_args "$@" || exit $?

# --------------------------------------------------------
# HELPERS
# --------------------------------------------------------
slugify() {
    echo "$1" | iconv -t ascii//TRANSLIT | sed -E 's/[^a-zA-Z0-9]+/-/g' | sed -E 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]'
}

BITRATE="${KW_ARGS[--bitrate]:-15000k}"
WM_WIDTH="${KW_ARGS[--wm-width]:-120}"
INPUT_PATH="${KW_ARGS[--input]:-${ARGS[0]:-.}}"

# CHECK: Accept either a directory (-d) OR a regular file (-f)
if [ ! -d "$INPUT_PATH" ] && [ ! -f "$INPUT_PATH" ]; then
    echo "❌ Error: Input file or directory not found: $INPUT_PATH"
    exit 1
fi

# Smart Output Directory Selection
if [ -d "$INPUT_PATH" ]; then
    OUTPUT_DIR="${KW_ARGS[--output]:-$INPUT_PATH}"
else
    OUTPUT_DIR="${KW_ARGS[--output]:-$(dirname "$INPUT_PATH")}"
fi
mkdir -p "$OUTPUT_DIR"

# --------------------------------------------------------
# PROCESSING LOOP
# --------------------------------------------------------
# Feed either the single file path or a directory list into the while loop
if [ -f "$INPUT_PATH" ]; then
    printf "%s\0" "$INPUT_PATH"
else
    find "$INPUT_PATH" -maxdepth 1 -name "*.mp4" -print0
fi | while IFS= read -r -d '' file; do
    
    filename=$(basename "$file")
    base_name="${filename%.*}"
    
    # ffprobe redirected from /dev/null to protect the loop's stdin
    WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$file" < /dev/null)
    
    [[ -z "$WIDTH" ]] && WIDTH=0

    echo "🎬 Analyzing: $filename (${WIDTH}px wide)"

    # We start with a format filter to ensure a clean slate
    V_FILTERS="format=pix_fmts=yuv420p" 
    NAME_SUFFIX=""

    # --------------------------------------------------------
    # SEQUENTIAL FILTER BUILDING
    # --------------------------------------------------------
    for arg in "$@"; do
        case $arg in
            --bloom)
                V_FILTERS="${V_FILTERS},split[a][b];[b]gblur=sigma=10[b];[a][b]blend=all_mode=addition:all_opacity=0.7"
                NAME_SUFFIX="${NAME_SUFFIX}-bloom"
                ;;
			--twinkle)
			    V_FILTERS="${V_FILTERS},geq=lum='p(X,Y)*(1+0.15*sin(2*PI*T*1.5))'"
			    NAME_SUFFIX="${NAME_SUFFIX}-twinkle"
			    ;;
            --aberration)
                V_FILTERS="${V_FILTERS},chromashift=cbh=2:cbv=2:crh=-2:crv=-2"
                NAME_SUFFIX="${NAME_SUFFIX}-distort"
                ;;
            --cartoon)
                V_FILTERS="${V_FILTERS},edgedetect=low=0.1:high=0.4,negate"
                NAME_SUFFIX="${NAME_SUFFIX}-toon"
                ;;
            --crush)
                V_FILTERS="${V_FILTERS},curves=all='0/0 0.1/0 1/1'"
                NAME_SUFFIX="${NAME_SUFFIX}-crush"
                ;;
            --grain)
                V_FILTERS="${V_FILTERS},noise=alls=8:allf=t"
                NAME_SUFFIX="${NAME_SUFFIX}-grain"
                ;;
            --glitch)
                V_FILTERS="${V_FILTERS},rgbashift=rh=3:bh=-3"
                NAME_SUFFIX="${NAME_SUFFIX}-glitch"
                ;;
        esac
    done

    # Apply LUT at the end if provided
    if [[ -n "${KW_ARGS[--lut]}" && -f "${KW_ARGS[--lut]}" ]]; then
        V_FILTERS="${V_FILTERS},lut3d=file='${KW_ARGS[--lut]}'"
        NAME_SUFFIX="${NAME_SUFFIX}-lut"
    fi

    output_name="${OUTPUT_DIR}/$(slugify "$base_name")${NAME_SUFFIX}.mp4"

    # RUN FFMPEG
    if [[ -n "${KW_ARGS[--watermark]}" && -f "${KW_ARGS[--watermark]}" ]]; then
        ffmpeg -nostdin -y -i "$file" -i "${KW_ARGS[--watermark]}" \
            -filter_complex "[1:v]scale=${WM_WIDTH}:-1[wm]; [0:v]${V_FILTERS}[base]; [base][wm]overlay=W-w-20:H-h-20" \
            -c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1 -c:a copy \
            "$output_name"
    else
        ffmpeg -nostdin -y -i "$file" \
            -filter_complex "${V_FILTERS}" \
            -c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1 -c:a copy \
            "$output_name"
    fi

    echo "✅ Finished: $output_name"
    echo "-----------------------------------"
done