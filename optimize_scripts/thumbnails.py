#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess
import tempfile
from pathlib import Path
from PIL import Image, ImageOps

VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".avi", ".webm", ".m4v", ".flv"}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff"}

def extract_video_frame(video_path: Path, timecode: str) -> Path:
    """Uses ffmpeg to grab a single frame from a video file."""
    temp_frame = Path(tempfile.mktemp(suffix=".png"))
    cmd = [
        "ffmpeg", "-v", "error", "-y",
        "-ss", timecode,
        "-i", str(video_path),
        "-frames:v", "1",
        "-q:v", "2",
        str(temp_frame)
    ]
    try:
        subprocess.run(cmd, check=True)
        if temp_frame.exists() and temp_frame.stat().st_size > 0:
            return temp_frame
    except Exception as e:
        print(f"❌ FFmpeg frame extraction failed for {video_path.name}: {e}")
    return None

def create_smart_thumbnail(img_path: Path, output_path: Path, width: int, height: int, quality: int = 85):
    """Resizes and smart-crops an image using PIL's Lanczos fitting (no stretching)."""
    try:
        with Image.open(img_path) as img:
            # ImageOps.fit fills the box and center-crops without distorting aspect ratio
            thumb = ImageOps.fit(img, (width, height), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
            
            # Convert RGBA to RGB for JPEG compatibility if needed
            if output_path.suffix.lower() in (".jpg", ".jpeg") and thumb.mode in ("RGBA", "P"):
                thumb = thumb.convert("RGB")
                
            output_path.parent.mkdir(parents=True, exist_ok=True)
            thumb.save(output_path, quality=quality, optimize=True)
            print(f"✨ Thumbnail Created: {output_path.name} [{width}x{height}]")
    except Exception as e:
        print(f"❌ Failed to process thumbnail for {img_path.name}: {e}")

def process_target(target_path: Path, width: int, height: int, timecode: str, output_dir: Path = None):
    ext = target_path.suffix.lower()
    
    # 1. Determine base destination
    if output_dir:
        dest_folder = output_dir
    else:
        dest_folder = target_path.parent / "thumbs"
        
    out_name = f"{target_path.stem}_{width}x{height}_thumb.jpg"
    dest_path = dest_folder / out_name

    # 2. Handle Video Input
    if ext in VIDEO_EXTENSIONS:
        print(f"🎥 Video detected: {target_path.name}. Extracting frame at {timecode}...")
        extracted_frame = extract_video_frame(target_path, timecode)
        if extracted_frame:
            create_smart_thumbnail(extracted_frame, dest_path, width, height)
            extracted_frame.unlink(missing_ok=True) # Cleanup temporary frame
            
    # 3. Handle Image Input
    elif ext in IMAGE_EXTENSIONS:
        create_smart_thumbnail(target_path, dest_path, width, height)

def main():
    parser = argparse.ArgumentParser(description="Smart Thumbnailer & Video Frame Generator")
    parser.add_argument("path", help="Path to an image/video file or folder")
    parser.add_argument("--width", type=int, default=500, help="Thumbnail width in px (default: 500)")
    parser.add_argument("--height", type=int, default=500, help="Thumbnail height in px (default: 500)")
    parser.add_argument("--youtube", action="store_true", help="Shortcut for YouTube thumbnail dimensions (1280x720)")
    parser.add_argument("--timecode", default="00:00:01", help="Video timecode to grab frame from (default: 00:00:01)")
    parser.add_argument("--output-dir", help="Optional output folder for thumbnails")

    args = parser.parse_args()

    # Apply YouTube shortcut if passed
    width = 1280 if args.youtube else args.width
    height = 720 if args.youtube else args.height

    target = Path(args.path)
    if not target.exists():
        print(f"❌ Path not found: {target}")
        sys.exit(1)

    out_dir = Path(args.output_dir) if args.output_dir else None

    if target.is_file():
        process_target(target, width, height, args.timecode, out_dir)
    elif target.is_dir():
        all_files = [p for p in target.iterdir() if p.suffix.lower() in (IMAGE_EXTENSIONS | VIDEO_EXTENSIONS)]
        print(f"📂 Found {len(all_files)} target file(s) in {target}...")
        for file in all_files:
            process_target(file, width, height, args.timecode, out_dir)

if __name__ == "__main__":
    main()