#!/usr/bin/env bash
#
# snapshot.sh – Beautiful code screenshots with silicon + ImageMagick + Gum
#
set -eo pipefail # Removed -u to play nice with internal arg logic

# ──────────────────────────────────────────────────────────────────────────────
# 1. Dependency Check
# ──────────────────────────────────────────────────────────────────────────────
for cmd in silicon magick gum; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed."
        exit 1
    fi
done

# Colors
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  CYAN=$(tput setaf 6)
else
  BOLD="" RESET="" RED="" GREEN="" YELLOW="" CYAN=""
fi

print_success() { echo "${GREEN}✓${RESET} $1"; }
print_info()    { echo "${CYAN}→${RESET} $1"; }
print_warning() { echo "${YELLOW}⚠${RESET} $1" >&2; }
print_error()   { echo "${RED}✗${RESET} $1" >&2; }

# ──────────────────────────────────────────────────────────────────────────────
# 2. Default Values
# ──────────────────────────────────────────────────────────────────────────────
INPUT=""
THEME="cyberpunk"
FONT="FiraMono Nerd Font Mono"
OUTPUT_DIR="./screenshots"
ROUNDED=false
VIGNETTE=false

# ──────────────────────────────────────────────────────────────────────────────
# 3. Argument Parsing (The Clean Way)
# ──────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)   INPUT="$2"; shift 2 ;;
        -t|--theme)   THEME="$2"; shift 2 ;;
        -f|--font)    FONT="$2"; shift 2 ;;
        -o|--output)  OUTPUT_DIR="$2"; shift 2 ;;
        --rounded)    ROUNDED=true; shift ;;
        --vignette)   VIGNETTE=true; shift ;;
        -h|--help)
            gum style --foreground 212 "Usage: ./snapshot.sh [options]"
            echo "  -i, --input <file>   File or directory to snap"
            echo "  -t, --theme <name>   cyberpunk, 1980, basic"
            echo "  --rounded            Enable rounded corners"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ──────────────────────────────────────────────────────────────────────────────
# 4. Interactive Fallback (The Gum Magic)
# ──────────────────────────────────────────────────────────────────────────────

# If no input is provided, use Gum to let the user pick a file
if [[ -z "$INPUT" ]]; then
    gum style --foreground 212 --border double --align center --width 40 "Snapshot" "Select a file to process"
    INPUT=$(gum file .)
fi

# Theme Selection if invalid
# Theme Selection - Updated with exact Silicon names
case "$THEME" in
    cyberpunk) 
        SIL_THEME="Monokai Extended"
        BG="#0d0e17"
        SHAD="#ff005580" 
        ;;
    1980)      
        SIL_THEME="Tomorrow Night"
        BG="#2d2d2d"
        SHAD="#000000a0" 
        ;;
    *)         
        SIL_THEME="Dracula"
        BG="#282a36"
        SHAD="#00000080" 
        ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# 5. Execution
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# Collect files – Clean, reliable, and easy to edit
# ──────────────────────────────────────────────────────────────────────────────

# ← Add or remove extensions here (one per line, no quotes needed)
SUPPORTED_EXTENSIONS=(
  py php html htm
  js jsx ts tsx
  rs go sh bash
  rb css scss
  json yaml yml toml
  md markdown
)

FILES=()

if [[ -d "$INPUT" ]]; then
  # Build proper OR conditions
  conditions=()
  for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
    conditions+=(-o -name "*.${ext}")
  done

  # Remove the first "-o"
  if (( ${#conditions[@]} > 0 )); then
    conditions=("${conditions[@]:1}")
  fi

  mapfile -t FILES < <(
    find "$INPUT" \
      -not -path '*/.*' \
      -not -path '*/node_modules/*' \
      -not -path '*/venv/*' \
      -not -path '*/__pycache__/*' \
      -not -path '*/target/*' \
      -type f \
      \( "${conditions[@]}" \) \
      2>/dev/null | sort
  )
else
  # Single file
  FILES=("$INPUT")
fi

# Final check
if (( ${#FILES[@]} == 0 )); then
  print_error "No supported files found in '${INPUT}'."
  echo "Supported extensions: ${SUPPORTED_EXTENSIONS[*]}"
  echo "Files found by tree:"
  tree "$INPUT" 2>/dev/null || ls -la "$INPUT"
  exit 1
fi

print_info "Found ${#FILES[@]} file(s) to process"

for file in "${FILES[@]}"; do
    filename=$(basename "$file")
    out_file="$OUTPUT_DIR/${filename%.*}.png"

    # Use a Gum Spinner for the heavy lifting
    gum spin --spinner dot --title " Snapping $filename..." -- sleep 0.2

    # 1. Run Silicon
    silicon "$file" \
        -o "$out_file" \
        --theme "$SIL_THEME" \
        --background "$BG" \
        --font "$FONT" \
        --shadow-color "$SHAD" \
        --shadow-blur-radius 30

    # 2. Run ImageMagick Enhancements
    if [[ "$ROUNDED" == true ]]; then
        gum spin --spinner monkey --title " Rounding corners..." -- \
        magick "$out_file" \
        \( +clone -alpha extract -draw "roundrectangle 0,0 %[fx:w],%[fx:h] 40,40" \) \
        -alpha off -compose CopyOpacity -composite "$out_file"
    fi

    if [[ "$VIGNETTE" == true ]]; then
        magick "$out_file" \( +clone -background black -vignette 0x20 -channel A -separate \) \
        -compose Multiply -composite "$out_file"
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# 6. Success Message
# ──────────────────────────────────────────────────────────────────────────────
echo ""
gum style \
	--foreground 212 --border-foreground 212 --border normal \
	--align center --width 40 \
	"✨ Success!" "Files saved to $OUTPUT_DIR"