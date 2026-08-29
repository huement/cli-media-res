import argparse
import os
import random
import sys
from io import BytesIO
from PIL import Image, ImageOps, ImageColor

# --- Optional Dependencies ---
try:
    import climage
    CLIMAGE_AVAILABLE = True
except ImportError:
    CLIMAGE_AVAILABLE = False

try:
    import cairosvg
    CAIROSVG_AVAILABLE = True
except ImportError:
    CAIROSVG_AVAILABLE = False


DEFAULT_INPUT_DIR = 'input_images'
DEFAULT_OUTPUT_DIR = 'output_images'


def load_image(input_path):
    """Loads raster or vector images (SVG) safely into a PIL Image."""
    ext = os.path.splitext(input_path)[1].lower()

    if ext == '.svg':
        if not CAIROSVG_AVAILABLE:
            raise ImportError("SVG file supplied, but 'cairosvg' is not installed. Install via 'pip install cairosvg'.")
        # Convert SVG to PNG in memory
        png_bytes = cairosvg.svg2png(url=input_path)
        return Image.open(BytesIO(png_bytes)).convert('RGBA')

    return Image.open(input_path)


def apply_distress_to_small_image(small_img, intensity_percent, decay_rate):
    """Applies a 'chipped edge' effect directly to the low-res pixel grid."""
    if not (0 < intensity_percent <= 100):
        return small_img

    small_img = small_img.convert('RGBA') if small_img.mode != 'RGBA' else small_img.copy()

    if not (0.0 < decay_rate <= 1.0):
        decay_rate = 0.65

    pixels = small_img.load()
    grid_width, grid_height = small_img.size
    initial_probability = intensity_percent / 100.0

    for by in range(grid_height):
        for bx in range(grid_width):
            dist_x = min(bx, grid_width - 1 - bx)
            dist_y = min(by, grid_height - 1 - by)
            distance_from_edge = min(dist_x, dist_y)
            adjusted_probability = initial_probability * (decay_rate ** distance_from_edge)

            if random.random() < adjusted_probability:
                r, g, b, _ = pixels[bx, by]
                pixels[bx, by] = (r, g, b, 0)

    return small_img

def colorize_image(img, primary_color="red", highlight_color="#FF8888"):
    """Remaps black/gray pixels to shades of the target color."""
    original_mode = img.mode
    has_alpha = 'A' in img.getbands()

    alpha = img.getchannel('A') if has_alpha else None

    # Convert to grayscale to measure pixel brightness (0 = black, 255 = white)
    gray = img.convert('L')

    # Map black pixels (0) to primary_color, and bright pixels (255) to highlight_color
    colorized = ImageOps.colorize(
        gray,
        black=ImageColor.getrgb(primary_color),
        white=ImageColor.getrgb(highlight_color)
    )

    if has_alpha:
        colorized.putalpha(alpha)
        return colorized.convert('RGBA')

    return colorized.convert('RGB')

def pixelate_image(input_path, output_path, pixel_size, color_count=None, distress_intensity=0, decay_rate=0.65, tint_color=False):
    """Pixelates an image, preserving transparency and optionally adding distressed edges."""
    if pixel_size <= 0:
        print("Error: Pixel size must be greater than 0.")
        return False

    output_ext = os.path.splitext(output_path)[1].lower()
    if distress_intensity > 0 and output_ext != '.png':
        print("Warning: Distress effect modifies transparency. Output format should ideally be PNG.")

    try:
        print(f"Processing '{os.path.basename(input_path)}'...")
        img = load_image(input_path)
        original_size = img.size
        original_has_alpha = img.mode in ('RGBA', 'LA') or ('transparency' in img.info)

        # Apply the colorize filter
        if tint_color:
            img = colorize_image(img, primary_color=tint_color) # type: ignore

        # 1. Prepare Alpha / Mode
        if original_has_alpha or distress_intensity > 0:
            img = img.convert('RGBA')
            current_mode = 'RGBA'
        else:
            img = img.convert('RGB')
            current_mode = 'RGB'

        # 2. Downscale using BOX filter (cleaner color averages for pixel art than LANCZOS)
        small_width = max(1, original_size[0] // pixel_size)
        small_height = max(1, original_size[1] // pixel_size)
        processed_small_img = img.resize((small_width, small_height), Image.Resampling.BOX)

        # 3. Quantize Colors (Optional)
        if color_count is not None and color_count > 0:
            if processed_small_img.mode == 'RGBA':
                alpha = processed_small_img.getchannel('A')
                rgb_img = processed_small_img.convert('RGB')
                quantized_rgb = rgb_img.quantize(colors=color_count, method=Image.Quantize.MEDIANCUT).convert('RGB')
                processed_small_img = quantized_rgb
                processed_small_img.putalpha(alpha)
            else:
                processed_small_img = processed_small_img.quantize(colors=color_count, method=Image.Quantize.MEDIANCUT).convert('RGB')
                if distress_intensity > 0:
                    processed_small_img = processed_small_img.convert('RGBA')

        # 4. Apply Distress Edges (Optional)
        if distress_intensity > 0:
            processed_small_img = apply_distress_to_small_image(processed_small_img, distress_intensity, decay_rate)
            current_mode = 'RGBA'

        # 5. Upscale back to original size
        pixelated_img = processed_small_img.resize(original_size, Image.Resampling.NEAREST)

        if current_mode == 'RGBA' and pixelated_img.mode != 'RGBA':
            pixelated_img = pixelated_img.convert('RGBA')

        # 6. Save
        pixelated_img.save(output_path)
        print(f"-> Saved pixelated image to '{output_path}'")
        return True

    except Exception as e:
        print(f"An error occurred while processing {os.path.basename(input_path)}: {e}")
        return False


def render_terminal_preview(image_path, width=80):
    """Outputs the saved image directly to the CLI using climage."""
    if not CLIMAGE_AVAILABLE:
        print("\n[!] Cannot render terminal preview: 'climage' is not installed. (pip install climage)")
        return

    try:
        # climage automatically converts RGB/RGBA images into ANSI terminal color sequences
        output = climage.convert(image_path, width=width)
        print("\n--- Terminal Preview ---")
        print(output)
    except Exception as e:
        print(f"Failed to render terminal preview: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Turn raster PNGs or SVG vectors into pixel art with terminal preview support.",
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument("input_image", help="Path to input file (PNG, JPG, SVG, etc.)")
    parser.add_argument("-o", "--output", help="Full path for the output file.")
    parser.add_argument("--input-dir", default=DEFAULT_INPUT_DIR, help=f"Default: '{DEFAULT_INPUT_DIR}'")
    parser.add_argument("--output-dir", default=DEFAULT_OUTPUT_DIR, help=f"Default: '{DEFAULT_OUTPUT_DIR}'")

    # Pixelation controls
    parser.add_argument("-p", "--pixel-size", type=int, default=8, help="Block size in pixels (default: 8)")
    parser.add_argument("-c", "--colors", type=int, default=None, help="Max color palette count")
    parser.add_argument("-d", "--distress-edges", type=int, default=0, metavar='PERCENT', help="Chipping chance (1-100)")
    parser.add_argument("--decay-rate", type=float, default=0.65, metavar='RATE', help="Distress decay rate (0.0 - 1.0)")

    # Colorize
    parser.add_argument("--tint", type=str, default=None,
                        help="Colorize black/gray pixels (e.g., 'red', '#FF0000', 'crimson')")

    # Terminal rendering flag
    parser.add_argument("-t", "--terminal", action="store_true", help="Print the generated pixel art in the terminal")
    parser.add_argument("--tw", "--terminal-width", type=int, default=60, help="Terminal display width in characters (default: 60)")

    args = parser.parse_args()

    # Determine input path
    full_input_path = args.input_image if os.path.dirname(args.input_image) else os.path.join(args.input_dir, args.input_image)
    if not os.path.isfile(full_input_path):
        print(f"Error: Input file not found: {full_input_path}")
        return

    # Determine output path
    if args.output:
        full_output_path = args.output
    else:
        input_name = os.path.splitext(os.path.basename(full_input_path))[0]
        full_output_path = os.path.join(args.output_dir, f"pixel_{input_name}.png")
        counter = 1
        while os.path.exists(full_output_path):
            full_output_path = os.path.join(args.output_dir, f"pixel_{input_name}_{counter}.png")
            counter += 1

    os.makedirs(os.path.dirname(full_output_path) or '.', exist_ok=True)

    # Execute conversion
    success = pixelate_image(
        input_path=full_input_path,
        output_path=full_output_path,
        pixel_size=args.pixel_size,
        color_count=args.colors,
        distress_intensity=args.distress_edges,
        decay_rate=args.decay_rate,
        tint_color=args.tint
    )

    # Terminal output pass
    if success and args.terminal:
        render_terminal_preview(full_output_path, width=args.tw)


if __name__ == "__main__":
    main()
