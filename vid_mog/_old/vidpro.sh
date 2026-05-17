#!/usr/bin/env bash

# 1. Source the bash-args library
source "$(dirname "$0")/../bash-args.sh"

# --------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------
DESCRIPTION="Smart Video Optimizer: Upscales low-res, preserves high-res, adds effects."

KEYWORDS=(
    "--input|-i;string"
    "--output|-o;string"
    "--lut|-l;string"
    "--grain|-gr;bool"
    "--glitch|-gl;bool"
    "--slowsmooth;bool"
    "--ghosting;bool"
    "--watermark|-wm;string"
    "--wm-width|-ww;int"
    "--bitrate|-b;string"
)

declare -A USAGE
USAGE["--input"]="Input folder containing mp4 files."
USAGE["--output"]="Output folder for processed files."
USAGE["--lut"]="Path to the .cube LUT file."
USAGE["--grain"]="Enable film grain effect."
USAGE["--glitch"]="Enable anaglyphic RGB shift glitch effect."
USAGE["--slowsmooth"]="Enable ultra-smooth motion interpolation slow-mo (50% speed, 60fps)."
USAGE["--ghosting"]="Enable dreamy frame-blending slow-mo (50% speed, 60fps)."
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
INPUT_DIR="${KW_ARGS[--input]:-${ARGS[0]:-.}}"

if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ Error: Input directory not found: $INPUT_DIR"
    exit 1
fi

OUTPUT_DIR="${KW_ARGS[--output]:-$INPUT_DIR}"
mkdir -p "$OUTPUT_DIR"

# --------------------------------------------------------
# PROCESSING LOOP
# --------------------------------------------------------
find "$INPUT_DIR" -maxdepth 1 -name "*.mp4" -print0 | while IFS= read -r -d '' file; do
    
    filename=$(basename "$file")
    base_name="${filename%.*}"
    
    # ffprobe redirected from /dev/null to protect the loop's stdin
    WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$file" < /dev/null)
    
    [[ -z "$WIDTH" ]] && WIDTH=0

    echo "🎬 Analyzing: $filename (${WIDTH}px wide)"

    V_FILTERS="hqdn3d=0.5:0.5:3:3" 
    NAME_SUFFIX=""
    
    # Default audio configuration (Direct stream copy)
    A_ARGS="-c:a copy"

    if [ "$WIDTH" -lt 1920 ] && [ "$WIDTH" -gt 0 ]; then
        echo "    -> Upscaling to 1080p..."
        V_FILTERS="${V_FILTERS},scale=1920:1080:flags=lanczos,unsharp=3:3:0.5:3:3:0.5"
        NAME_SUFFIX="${NAME_SUFFIX}-1080"
    else
        echo "    -> Skipping resize (1080p+ or undetected)."
        NAME_SUFFIX="${NAME_SUFFIX}-orig"
    fi

    # Optional Visual Effects
    [[ "${KW_ARGS[--glitch]}" == "true" ]] && { V_FILTERS="${V_FILTERS},rgbashift=rh=3:bh=-3"; NAME_SUFFIX="${NAME_SUFFIX}-glitch"; }
    [[ "${KW_ARGS[--grain]}" == "true" ]] && { V_FILTERS="${V_FILTERS},noise=alls=8:allf=t"; NAME_SUFFIX="${NAME_SUFFIX}-grain"; }
    
    # Slow Motion Implementations
    if [[ "${KW_ARGS[--slowsmooth]}" == "true" ]]; then
        echo "    -> Applying Ultra-Smooth Motion Interpolation (50% Speed)..."
        V_FILTERS="${V_FILTERS},setpts=2*PTS,minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:vsbmc=1"
        A_ARGS="-c:a aac -af atempo=0.5"
        NAME_SUFFIX="${NAME_SUFFIX}-slowsmooth"
    elif [[ "${KW_ARGS[--ghosting]}" == "true" ]]; then
        echo "    -> Applying Dreamy Frame Blending / Light Trails (50% Speed)..."
        V_FILTERS="${V_FILTERS},setpts=2*PTS,minterpolate=fps=60:mi_mode=blend"
        A_ARGS="-c:a aac -af atempo=0.5"
        NAME_SUFFIX="${NAME_SUFFIX}-ghosting"
    fi
    
    if [[ -n "${KW_ARGS[--lut]}" && -f "${KW_ARGS[--lut]}" ]]; then
        V_FILTERS="${V_FILTERS},lut3d=file='${KW_ARGS[--lut]}'"
    fi

    V_FILTERS="${V_FILTERS},format=yuv420p"
    output_name="${OUTPUT_DIR}/$(slugify "$base_name")${NAME_SUFFIX}.mp4"

    # RUN FFMPEG: Note that $A_ARGS is left unquoted deliberately so bash splits the array options
    if [[ -n "${KW_ARGS[--watermark]}" && -f "${KW_ARGS[--watermark]}" ]]; then
        ffmpeg -nostdin -y -i "$file" -i "${KW_ARGS[--watermark]}" \
            -filter_complex "[1:v]scale=${WM_WIDTH}:-1[wm]; [0:v]${V_FILTERS}[base]; [base][wm]overlay=W-w-20:H-h-20" \
            -c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1 $A_ARGS \
            "$output_name"
    else
        ffmpeg -nostdin -y -i "$file" \
            -vf "$V_FILTERS" \
            -c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1 $A_ARGS \
            "$output_name"
    fi

    echo "✅ Finished: $output_name"
    echo "-----------------------------------"
done