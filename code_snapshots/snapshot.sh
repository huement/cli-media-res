#!/usr/bin/env bash
#
# snapshot.sh – Fixed & improved version

set -euo pipefail

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

# Check silicon
if ! command -v silicon >/dev/null 2>&1; then
  print_error "silicon not found. Install with: cargo install silicon"
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Defaults
# ──────────────────────────────────────────────────────────────────────────────

INPUT=""
OUTPUT_DIR=""
THEME="basic"
SHOW_NUMBERS=true
FONT="FiraCode Nerd Font Mono Med"
SHOW_WINDOW=true          # Now safe
SHOW_SHADOW=true
LOGO=""
ROUNDED=false
VIGNETTE=false
BORDER=false
OVERLAY_TEXT=""

# ──────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ──────────────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)      shift; INPUT="${1?--input requires value}"; shift ;;
    --input=*)       INPUT="${1#*=}"; shift ;;
    -o|--output)     shift; OUTPUT_DIR="${1?--output requires value}"; shift ;;
    --output=*)      OUTPUT_DIR="${1#*=}"; shift ;;
    -t|--theme)      shift; THEME="${1?--theme requires value}"; shift ;;
    --theme=*)       THEME="${1#*=}"; shift ;;
    --no-numbers)    SHOW_NUMBERS=false; shift ;;
    --font)          shift; FONT="${1?--font requires value}"; shift ;;
    --font=*)        FONT="${1#*=}"; shift ;;
    --no-window)     SHOW_WINDOW=false; shift ;;
    --no-shadow)     SHOW_SHADOW=false; shift ;;
    --logo)          shift; LOGO="${1?--logo requires value}"; shift ;;
    --logo=*)        LOGO="${1#*=}"; shift ;;
    --rounded)       ROUNDED=true; shift ;;
    --vignette)      VIGNETTE=true; shift ;;
    --border)        BORDER=true; shift ;;
    --text)          shift; OVERLAY_TEXT="${1?--text requires value}"; shift ;;
    --text=*)        OVERLAY_TEXT="${1#*=}"; shift ;;
    --no-color)      NO_COLOR=true; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 -i <path> [options]

Options:
  -i, --input <file|dir>     Required
  -o, --output <dir>
  -t, --theme basic|cyberpunk|1980 (default: basic)
      --no-window            Disable window chrome
      --no-shadow
      --rounded --vignette --border
      --font "Your Font"
      --text "Overlay text"
EOF
      exit 0
      ;;
    *) print_error "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$INPUT" ]] && { print_error "--input is required"; exit 1; }
[[ ! -e "$INPUT" ]] && { print_error "'$INPUT' does not exist"; exit 1; }

THEME=$(echo "$THEME" | tr '[:upper:]' '[:lower:]')

# ──────────────────────────────────────────────────────────────────────────────
# Theme presets
# ──────────────────────────────────────────────────────────────────────────────

case "$THEME" in
  basic)
    SILICON_THEME="OneHalfDark"
    BG_COLOR="#282a36"
    SHADOW_COLOR="#00000080"
    SHADOW_BLUR=28
    ;;
  cyberpunk)
    SILICON_THEME="Dracula"
    BG_COLOR="#0d0e17"                         # Very dark purple-black
    SHADOW_COLOR="#ff00ffaa"                   # Vibrant magenta neon
    SHADOW_BLUR=70                             # Large glowing halo
    ;;
  1980|eighties|1337)
    SILICON_THEME="1337"
    BG_COLOR="#2d2d2d"
    SHADOW_COLOR="#000000a0"
    SHADOW_BLUR=24
    ;;
  *)
    print_error "Unknown theme '$THEME'. Use: basic | cyberpunk | 1980"
    exit 1
    ;;
esac

# Output dir
if [[ -z "$OUTPUT_DIR" ]]; then
  if [[ -d "$INPUT" ]]; then
    OUTPUT_DIR="$INPUT/screenshots"
  else
    OUTPUT_DIR="$(dirname "$INPUT")/screenshots"
  fi
fi

mkdir -p "$OUTPUT_DIR"
print_info "Saving to: ${BOLD}$OUTPUT_DIR${RESET}"

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

# Silicon flags (fixed – no more --window-controls)
SILICON_BASE=(
  --font "$FONT"
  --theme "$SILICON_THEME"
  --background "$BG_COLOR"
)

[[ "$SHOW_NUMBERS" == false ]] && SILICON_BASE+=(--no-line-number)
[[ "$SHOW_SHADOW" == true ]] && SILICON_BASE+=(--shadow-color "$SHADOW_COLOR" --shadow-blur-radius "$SHADOW_BLUR")

# ──────────────────────────────────────────────────────────────────────────────
# Process files
# ──────────────────────────────────────────────────────────────────────────────

for file in "${FILES[@]}"; do
  print_info "Processing ${CYAN}$file${RESET}"

  lang="${file##*.}"
  lang="${lang,,}"
  [[ "$lang" == "sh" ]] && lang="bash"
  [[ "$lang" == "js" ]] && lang="javascript"

  base="$(basename "$file" | sed 's/\.[^.]*$//')"
  normal="$OUTPUT_DIR/${base}-${THEME}.png"
  big="$OUTPUT_DIR/${base}-${THEME}-2x.png"

  # Run silicon safely
  if silicon "${SILICON_BASE[@]}" --language "$lang" "$file" -o "$normal" 2>&1 | grep -v "No font found" || true; then
    if [[ -f "$normal" ]]; then
      print_success "Created: $normal"
    else
      print_error "silicon did not create the image"
      continue
    fi
  else
    print_error "silicon failed for $file"
    continue
  fi

  # ImageMagick enhancement
    if [[ -f "$normal" ]] && command -v magick >/dev/null 2>&1; then
      magick_cmd=(magick "$normal" -filter Lanczos -resize 200%)

      # === Remove the outer glow / shadow first ===
      magick_cmd+=(-fuzz 8% -trim +repage)

      if [[ "$ROUNDED" == true ]]; then
        magick_cmd+=(-alpha set -background none \
          \( +clone -fill white -colorize 100% -draw "roundRectangle 0,0 %[fx:w],%[fx:h] 32,32" \) \
          -compose DstIn -composite)
      fi

      if [[ "$VIGNETTE" == true ]]; then
        magick_cmd+=(\( +clone -background black -vignette 0x30+0+0 -channel A -separate \) \
          -compose Multiply -composite)
      fi

      if [[ "$BORDER" == true ]]; then
        magick_cmd+=(-bordercolor '#00ffff' -border 8)
      fi

      if [[ -n "$OVERLAY_TEXT" ]]; then
        magick_cmd+=(-gravity south -background '#00000080' -splice 0x80 \
          -fill '#00ff9f' -pointsize 32 -font "JetBrains-Mono" \
          -annotate +0+40 "$OVERLAY_TEXT")
      fi

      "${magick_cmd[@]}" "$big" && print_success "Enhanced: ${BOLD}$big${RESET}"
    elif [[ -f "$normal" ]]; then
      print_warning "ImageMagick not found – only basic version created"
    fi
done

echo
echo "${BOLD}${GREEN}✨ All done!${RESET} Check ${BOLD}$OUTPUT_DIR${RESET}"