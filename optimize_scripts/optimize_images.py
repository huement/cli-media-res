#!/usr/bin/env python3
import os
import sys
import argparse
from pathlib import Path
from PIL import Image

SUPPORTED_FORMATS = {".jpg", ".jpeg", ".png", ".webp"}

def format_size(num_bytes: int) -> str:
    """Formats raw byte counts into human-readable strings."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if abs(num_bytes) < 1024.0:
            return f"{num_bytes:3.1f} {unit}"
        num_bytes /= 1024.0
    return f"{num_bytes:.1f} TB"

def optimize_single_image(file_path: Path, quality: int, create_webp: bool):
    """Optimizes an image in-place and optionally creates a WebP variant."""
    ext = file_path.suffix.lower()
    if ext not in SUPPORTED_FORMATS:
        return

    orig_size = file_path.stat().st_size
    print(f"\n🖼️  Processing: {file_path.name} ({format_size(orig_size)})")

    try:
        with Image.open(file_path) as img:
            # 1. Save Optimized Version In-Place
            if ext in (".jpg", ".jpeg"):
                # Strip metadata, use progressive encoding
                if img.mode in ("RGBA", "P"):
                    img = img.convert("RGB")
                img.save(file_path, "JPEG", quality=quality, optimize=True, progressive=True)
            elif ext == ".png":
                img.save(file_path, "PNG", optimize=True)
            elif ext == ".webp":
                img.save(file_path, "WEBP", quality=quality, method=6)

            new_size = file_path.stat().st_size
            saved = orig_size - new_size
            pct = (saved / orig_size * 100) if orig_size > 0 else 0
            print(f"   ⚡ Optimized: {format_size(new_size)} (Saved {pct:.1f}%)")

            # 2. Create WebP Copy if requested
            if create_webp and ext != ".webp":
                webp_path = file_path.with_suffix(".webp")
                if img.mode not in ("RGB", "RGBA", "L", "LA"):
                    img = img.convert("RGBA" if "transparency" in img.info else "RGB")
                img.save(webp_path, "WEBP", quality=quality, method=6)
                webp_size = webp_path.stat().st_size
                print(f"   🌐 WebP Version Created: {webp_path.name} ({format_size(webp_size)})")

    except Exception as e:
        print(f"   ❌ Failed to optimize {file_path.name}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Image Optimization & WebP Conversion Tool")
    parser.add_argument("path", help="Path to image file or directory")
    parser.add_argument("--quality", type=int, default=80, help="Compression quality level 1-100 (default: 80)")
    parser.add_argument("--no-webp", action="store_true", help="Disable generating parallel .webp format copies")

    args = parser.parse_args()
    target = Path(args.path)

    if not target.exists():
        print(f"❌ Path not found: {target}")
        sys.exit(1)

    create_webp = not args.no_webp

    if target.is_file():
        optimize_single_image(target, args.quality, create_webp)
    elif target.is_dir():
        files = [p for p in target.rglob("*") if p.suffix.lower() in SUPPORTED_FORMATS]
        print(f"📂 Optimizing {len(files)} image(s) in {target}...")
        for f in files:
            optimize_single_image(f, args.quality, create_webp)

if __name__ == "__main__":
    main()