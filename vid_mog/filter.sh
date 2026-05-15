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
USAGE["--bloom"]="Adds a cinematic 'glow' to stars."
USAGE["--twinkle"]="Adds a shimmering animation to stars."
USAGE["--aberration"]="Adds chromatic lens distortion."
USAGE["--cartoon"]="Edge-detected cel-shaded look."
USAGE["--crush"]="Crushes blacks for deep space contrast."

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
    
    echo "🎬 Analyzing: $filename"

    # We start with a format filter to ensure a clean slate
    V_FILTERS="format=pix_fmts=yuv420p" 
    NAME_SUFFIX=""

    # --------------------------------------------------------
    # SEQUENTIAL FILTER BUILDING
    # This loop looks at every argument passed to the script 
    # and appends the filter in the order they were typed.
    # --------------------------------------------------------
    for arg in "$@"; do
        case $arg in
            --bloom)
                # Bloom uses a complex filter logic, so we wrap it in a sequence
                # Note: For simplicity in a single chain, we use a lighter bloom
                V_FILTERS="${V_FILTERS},split[a][b];[b]gblur=sigma=10[b];[a][b]blend=all_mode=addition:all_opacity=0.7"
                NAME_SUFFIX="${NAME_SUFFIX}-bloom"
                ;;
            --twinkle)
                V_FILTERS="${V_FILTERS},geq=lum='p(X,Y)*(1+0.15*sin(2*PI*t*1.5))'"
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
    # If the filter string contains semicolons (like Bloom), we MUST use -filter_complex
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