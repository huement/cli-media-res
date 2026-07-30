#!/usr/bin/env python3
import argparse
from pathlib import Path
from PIL import Image

def convert_png_to_webp(target_dir: str, quality: int = 80):
    folder = Path(target_dir)
    if not folder.is_dir():
        print(f"Error: Directory '{target_dir}' does not exist.")
        return

    png_files = list(folder.glob("*.png")) + list(folder.glob("*.PNG"))
    if not png_files:
        print(f"No PNG files found in '{target_dir}'.")
        return

    converted = 0
    for file_path in png_files:
        output_path = file_path.with_suffix(".webp")
        try:
            with Image.open(file_path) as img:
                img.save(output_path, format="WEBP", quality=quality)
            print(f"Converted: {file_path.name} → {output_path.name}")
            converted += 1
        except Exception as e:
            print(f"  [x] Failed to convert {file_path.name}: {e}")

    print("----------------------------------------")
    print(f"Done! Successfully converted {converted} file(s).")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Batch convert PNG images to WebP")
    parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: current dir)")
    parser.add_argument("--quality", type=int, default=80, help="WebP quality (1-100)")
    args = parser.parse_args()
    
    convert_png_to_webp(args.directory, args.quality)