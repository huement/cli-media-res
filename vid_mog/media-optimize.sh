#!/usr/bin/env bash

# 1. Source the bash-args library
source "$(dirname "$0")/../bash-args.sh"

# --------------------------------------------------------
# CONFIGURATION & CLI ARGUMENTS
# --------------------------------------------------------
DESCRIPTION="Ultimate Video Toolkit: Combines smart optimization, motion interpolation, and creative FX filters."

KEYWORDS=(
    "--input|-i;string"
    "--output|-o;string"
    "--optimize;bool"
    "--downscale|-ds;string"  # CHANGED: Swapped from bool to string
    "--bloom;bool"
    "--twinkle;bool"
    "--aberration;bool"
    "--cartoon;bool"
    "--crush;bool"
    "--grain|-gr;bool"
    "--glitch|-gl;bool"
    "--slowsmooth;bool"
    "--ghosting;bool"
    "--lut|-l;string"
    "--watermark|-wm;string"
    "--wm-width|-ww;int"
    "--bitrate|-b;string"
)

declare -A USAGE
USAGE["--input"]="Input folder containing mp4 files or a path to a single mp4 file."
USAGE["--output"]="Output folder for processed files."
USAGE["--optimize"]="Enable smart optimization (denoise and auto-upscale low-res videos to 1080p)."
USAGE["--downscale"]="Downscale video to target height proportion (e.g., 720p, 480) using libx264 CRF 24." # CHANGED: Updated description
USAGE["--bloom"]="Enable bloom / glow effect."
USAGE["--twinkle"]="Enable starfield twinkling effect."
USAGE["--aberration"]="Enable chromatic aberration effect."
USAGE["--cartoon"]="Enable cartoon toon shading effect."
USAGE["--crush"]="Enable deep black shadow crush curves."
USAGE["--grain"]="Enable film grain effect."
USAGE["--glitch"]="Enable anaglyphic RGB shift glitch effect."
USAGE["--slowsmooth"]="Enable ultra-smooth motion interpolation slow-mo (50% speed, 60fps)."
USAGE["--ghosting"]="Enable dreamy frame-blending slow-mo (50% speed, 60fps)."
USAGE["--lut"]="Path to the .cube LUT file."
USAGE["--watermark"]="Path to the watermark image."
USAGE["--wm-width"]="Width of the watermark (Default: 120)."
USAGE["--bitrate"]="Video bitrate (Default: 15000k)."

parse_args "$@" || exit $?

# --------------------------------------------------------
# HELPERS & INITIALIZATION
# --------------------------------------------------------
slugify() {
    echo "$1" | iconv -t ascii//TRANSLIT | sed -E 's/[^a-zA-Z0-9]+/-/g' | sed -E 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]'
}

BITRATE="${KW_ARGS[--bitrate]:-15000k}"
WM_WIDTH="${KW_ARGS[--wm-width]:-120}"
INPUT_PATH="${KW_ARGS[--input]:-${ARGS[0]:-.}}"

# Robust check for input types (accepts file OR directory)
if [ ! -d "$INPUT_PATH" ] && [ ! -f "$INPUT_PATH" ]; then
    echo "❌ Error: Input file or directory not found: $INPUT_PATH"
    exit 1
fi

# Dynamic output directory target mapping
if [ -d "$INPUT_PATH" ]; then
    OUTPUT_DIR="${KW_ARGS[--output]:-$INPUT_PATH}"
else
    OUTPUT_DIR="${KW_ARGS[--output]:-$(dirname "$INPUT_PATH")}"
fi
mkdir -p "$OUTPUT_DIR"

# --------------------------------------------------------
# PROCESSING LOOP
# --------------------------------------------------------
if [ -f "$INPUT_PATH" ]; then
    printf "%s\0" "$INPUT_PATH"
else
    find "$INPUT_PATH" -maxdepth 1 -name "*.mp4" -print0
fi | while IFS= read -r -d '' file; do
    
    filename=$(basename "$file")
    base_name="${filename%.*}"
    
    # Extract resolution width securely
    WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$file" < /dev/null)
    [[ -z "$WIDTH" ]] && WIDTH=0

    echo "🎬 Analyzing: $filename (${WIDTH}px wide)"

    # Base baseline pixel format structure
    V_FILTERS="format=pix_fmts=yuv420p" 
    NAME_SUFFIX=""
    
    # Safe array allocation for structural audio and video codec adjustments
    A_ARGS=(-c:a copy)
    V_ARGS=(-c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1)

    # 1. SMART OPTIMIZATION (Denoise & Adaptive Upscale Layout)
    if [[ "${KW_ARGS[--optimize]}" == "true" ]]; then
        V_FILTERS="${V_FILTERS},hqdn3d=0.5:0.5:3:3"
        if [ "$WIDTH" -lt 1920 ] && [ "$WIDTH" -gt 0 ]; then
            echo "    -> Upscaling to 1080p..."
            V_FILTERS="${V_FILTERS},scale=1920:1080:flags=lanczos,unsharp=3:3:0.5:3:3:0.5"
            NAME_SUFFIX="${NAME_SUFFIX}-1080"
        else
            echo "    -> Skipping resize (1080p+ or undetected)."
            NAME_SUFFIX="${NAME_SUFFIX}-orig"
        fi
    fi

    # 1b. DOWNSCALING PIPELINE (CHANGED SECTION)
    if [[ -n "${KW_ARGS[--downscale]}" ]]; then
        # Sanitize input: extracts only numbers (e.g., '720p' or '720' both become '720')
        DS_SIZE=$(echo "${KW_ARGS[--downscale]}" | sed 's/[^0-9]//g')
        
        # Emergency fallback to 480 if the string argument didn't contain a valid number
        [[ -z "$DS_SIZE" ]] && DS_SIZE=480

        echo "    -> Downscaling to ${DS_SIZE}p..."
        V_FILTERS="${V_FILTERS},scale=-2:${DS_SIZE}"
        V_ARGS=(-c:v libx264 -crf 24)
        NAME_SUFFIX="${NAME_SUFFIX}-${DS_SIZE}"
    fi

    # 2. MOTION INTERPOLATION / SLOW MOTION
    if [[ "${KW_ARGS[--slowsmooth]}" == "true" ]]; then
        echo "    -> Applying Ultra-Smooth Motion Interpolation (50% Speed)..."
        V_FILTERS="${V_FILTERS},setpts=2*PTS,minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:vsbmc=1"
        A_ARGS=(-c:a aac -af "atempo=0.5")
        NAME_SUFFIX="${NAME_SUFFIX}-slowsmooth"
    elif [[ "${KW_ARGS[--ghosting]}" == "true" ]]; then
        echo "    -> Applying Dreamy Frame Blending / Light Trails (50% Speed)..."
        V_FILTERS="${V_FILTERS},setpts=2*PTS,minterpolate=fps=60:mi_mode=blend"
        A_ARGS=(-c:a aac -af "atempo=0.5")
        NAME_SUFFIX="${NAME_SUFFIX}-ghosting"
    fi

    # 3. CREATIVE FX PIPELINE
    if [[ "${KW_ARGS[--bloom]}" == "true" ]]; then
        V_FILTERS="${V_FILTERS},split[a][b];[b]gblur=sigma=10[b];[a][b]blend=all_mode=addition:all_opacity=0.7"
        NAME_SUFFIX="${NAME_SUFFIX}-bloom"
    fi
    if [[ "${KW_ARGS[--twinkle]}" == "true" ]]; then
        V_FILTERS="${V_FILTERS},geq=lum='p(X,Y)*(1+0.15*sin(2*PI*T*1.5))'"
        NAME_SUFFIX="${NAME_SUFFIX}-twinkle"
    fi
    if [[ "${KW_ARGS[--aberration]}" == "true" ]]; then
        V_FILTERS="${V_FILTERS},chromashift=cbh=10:cbv=4:crh=-10:crv=-4"
        NAME_SUFFIX="${NAME_SUFFIX}-distort"
    fi
    if [[ "${KW_ARGS[--cartoon]}" == "true" ]]; then
        V_FILTERS="${V_FILTERS},edgedetect=low=0.1:high=0.4,negate"
        NAME_SUFFIX="${NAME_SUFFIX}-toon"
    fi
    if [[ "${KW_ARGS[--crush]}" == "true" ]]; then
        V_FILTERS="${V_FILTERS},curves=all='0/0 0.1/0 1/1'"
        NAME_SUFFIX="${NAME_SUFFIX}-crush"
    fi
    if [[ "${KW_ARGS[--glitch]}" == "true" ]]; then
        V_FILTERS="${V_FILTERS},rgbashift=rh=3:bh=-3"
        NAME_SUFFIX="${NAME_SUFFIX}-glitch"
    fi
    if [[ "${KW_ARGS[--grain]}" == "true" ]]; then
        V_FILTERS="${V_FILTERS},noise=alls=8:allf=t"
        NAME_SUFFIX="${NAME_SUFFIX}-grain"
    fi

	# 4. COLOR GRADING (LUT Processing)
    if [[ -n "${KW_ARGS[--lut]}" && -f "${KW_ARGS[--lut]}" ]]; then
        V_FILTERS="${V_FILTERS},lut3d=file='${KW_ARGS[--lut]}'"
        NAME_SUFFIX="${NAME_SUFFIX}-lut"
    
        # SMART UPGRADE: If using a LUT and NOT downscaling, upgrade to a 10-bit GPU workflow
        if [[ -z "${KW_ARGS[--downscale]}" ]]; then
            echo "    -> 💎 Professional 10-bit color workflow activated for LUT processing."
            V_FILTERS=$(echo "$V_FILTERS" | sed 's/format=pix_fmts=yuv420p/format=pix_fmts=p010le/')
            # ADDED: -pix_fmt p010le right into V_ARGS below so the encoder knows it's getting 10-bit data
            V_ARGS=(-c:v hevc_videotoolbox -profile:v main10 -pix_fmt p010le -b:v "$BITRATE" -tag:v hvc1)
        fi
    fi
	
    # Fallback suffix adjustment to safeguard against source mutations
    if [[ -z "$NAME_SUFFIX" ]]; then
        NAME_SUFFIX="-processed"
    fi

    output_name="${OUTPUT_DIR}/$(slugify "$base_name")${NAME_SUFFIX}.mp4"

    # 5. EXECUTE FFMPEG CODES
    if [[ -n "${KW_ARGS[--watermark]}" && -f "${KW_ARGS[--watermark]}" ]]; then
        ffmpeg -nostdin -y -i "$file" -i "${KW_ARGS[--watermark]}" \
            -filter_complex "[1:v]scale=${WM_WIDTH}:-1[wm]; [0:v]${V_FILTERS}[base]; [base][wm]overlay=W-w-20:H-h-20" \
            "${V_ARGS[@]}" "${A_ARGS[@]}" \
            "$output_name"
    else
        ffmpeg -nostdin -y -i "$file" \
            -filter_complex "${V_FILTERS}" \
            "${V_ARGS[@]}" "${A_ARGS[@]}" \
            "$output_name"
    fi

    echo "✅ Finished: $output_name"
    echo "-----------------------------------"
done