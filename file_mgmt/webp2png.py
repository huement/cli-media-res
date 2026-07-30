#!/usr/bin/env python3
import argparse
from pathlib import Path
from PIL import Image

def convert_webp_to_png(input_file: str, output_dir: str = "."):
    inp_path = Path(input_file)
    if not inp_path.is_file():
        print(f"Error: File not found '{input_file}'")
        return

    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    base_name = inp_path.stem
    out_1x = out_dir / f"{base_name}.png"
    out_150 = out_dir / f"{base_name}_150pct.png"

    try:
        with Image.open(inp_path) as img:
            # 1:1 PNG
            img.save(out_1x, format="PNG")
            print(f"Converted 1:1: '{inp_path.name}' → '{out_1x.name}'")

            # 150% Lanczos upscaled PNG
            new_size = (int(img.width * 1.5), int(img.height * 1.5))
            resized_img = img.resize(new_size, Image.Resampling.LANCZOS)
            resized_img.save(out_150, format="PNG")
            print(f"Created 150% upscale: '{out_150.name}'")

        print("Done!")
    except Exception as e:
        print(f"Error converting WebP file: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert WebP to 1:1 PNG and 150% upscaled PNG")
    parser.add_argument("file", help="Input .webp file")
    parser.add_argument("--output-dir", default=".", help="Output directory")
    args = parser.parse_args()
    
    convert_webp_to_png(args.file, args.output_dir)