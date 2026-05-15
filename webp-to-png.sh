#!/usr/bin/env bash
# webp-to-png.sh
# Usage: ./webp-to-png.sh <input.webp> [output_dir]
#
# Converts a .webp image to PNG and also writes a second PNG
# upscaled to 150% of the original dimensions.
#
# Outputs:
#   <name>.png         — 1:1 PNG conversion
#   <name>_150pct.png  — PNG upscaled to 150%
#
# Requires ImageMagick (brew install imagemagick).

set -euo pipefail

# ── helpers ────────────────────────────────────────────────────────────────────
die()  { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# ── argument handling ───────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && die "Usage: $(basename "$0") <input.webp> [output_dir]"

INPUT="$1"
OUTPUT_DIR="${2:-.}"   # default: same directory as script caller

[[ -f "$INPUT" ]] || die "File not found: $INPUT"

# Accept .webp files only (case-insensitive)
case "${INPUT,,}" in
  *.webp) ;;
  *) die "Input file must be a .webp image (got: $INPUT)" ;;
esac

# ── locate ImageMagick ──────────────────────────────────────────────────────────
# ImageMagick 7 ships the unified 'magick' binary.
# ImageMagick 6 (macOS system / older Homebrew) uses 'convert'.
if command -v magick &>/dev/null; then
  IM_CMD="magick"
elif command -v convert &>/dev/null; then
  IM_CMD="convert"
else
  die "ImageMagick is not installed. Install with: brew install imagemagick"
fi

info "Using ImageMagick command: $IM_CMD"

# ── derive output paths ─────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
BASENAME="$(basename "${INPUT%.*}")"
OUT_1X="${OUTPUT_DIR}/${BASENAME}.png"
OUT_150="${OUTPUT_DIR}/${BASENAME}_150pct.png"

# ── convert: 1:1 PNG ────────────────────────────────────────────────────────────
info "Converting '$INPUT' → '$OUT_1X'"
"$IM_CMD" "$INPUT" "$OUT_1X"

# ── convert: 150% upscaled PNG ─────────────────────────────────────────────────
# -resize 150% preserves aspect ratio; Lanczos gives good upscale quality.
info "Creating 150%% upscaled copy → '$OUT_150'"
"$IM_CMD" "$INPUT" -filter Lanczos -resize 150% "$OUT_150"

info "Done."
info "  Original PNG : $OUT_1X"
info "  Upscaled PNG : $OUT_150"
