#!/usr/bin/env python3
import subprocess
import os
import sys
import tempfile
import re
import shutil
import argparse
import shlex
from pathlib import Path

def slugify(text):
    """Converts 'My Folder Name!' into 'my-folder-name'"""
    text = text.lower()
    text = re.sub(r'[^a-z0-9]+', '-', text)
    return text.strip('-')

class CyberGif:
    def __init__(self, fps=12, hold=2.0, fade=0.5):
        self.fps = fps
        self.hold = hold
        self.fade = fade
        self.total_dur = hold + (fade * 2)
        self.fade_out_start = hold + fade
        self.width = None
        self.height = None

    def get_image_dimensions(self, img_path):
        """Uses ffprobe to extract the width and height of an image."""
        cmd = [
            "ffprobe", "-v", "error", 
            "-select_streams", "v:0", 
            "-show_entries", "stream=width,height", 
            "-of", "csv=s=x:p=0", 
            str(img_path)
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        dimensions = result.stdout.strip().split('x')
        return int(dimensions[0]), int(dimensions[1])

    def find_minimum_dimensions(self, images):
        """Scans all images to find the absolute smallest bounding box."""
        min_w = float('inf')
        min_h = float('inf')
        
        print("🔍 Analyzing image resolutions...")
        for img in images:
            w, h = self.get_image_dimensions(img)
            if w < min_w: min_w = w
            if h < min_h: min_h = h
            
        return min_w, min_h

    def process_directory(self, input_dir):
        input_path = Path(input_dir).resolve()
        
        if not input_path.is_dir():
            print(f"❌ Skipping: '{input_dir}' is not a valid directory.")
            return

        # Gather images
        images = sorted([f for f in input_path.glob("*.png") if not f.name.startswith('.')])
        if not images:
            print(f"⚠️  No PNGs found in {input_path.name}")
            return

        # STEP 1: Dynamically find the target size (Smart Crop Bounding Box)
        self.width, self.height = self.find_minimum_dimensions(images)
        print(f"📐 Target Resolution Auto-Detected: {self.width}x{self.height}")

        # Generate slugified name from directory name
        output_name = f"{slugify(input_path.name)}.gif"
        output_path = Path.cwd() / output_name

        print(f"🎬 Processing '{input_path.name}' -> {output_name} ({len(images)} frames)")

        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            clip_list_path = tmp_path / "clips.txt"
            
            # STEP 2: Generate individual clips with Aspect-Fill and Fades
            rendered_clips = []
            for i, img in enumerate(images):
                clip_path = tmp_path / f"clip_{i:03d}.mp4"
                
                filter_str = (
                    f"scale={self.width}:{self.height}:force_original_aspect_ratio=increase,"
                    f"crop={self.width}:{self.height},"
                    f"setsar=1,"
                    f"fade=t=in:st=0:d={self.fade},"
                    f"fade=t=out:st={self.fade_out_start}:d={self.fade}"
                )

                cmd = [
                    "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                    "-loop", "1", "-i", str(img),
                    "-t", str(self.total_dur),
                    "-vf", filter_str,
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "ultrafast",
                    str(clip_path)
                ]
                
                subprocess.run(cmd, check=True)
                rendered_clips.append(clip_path)

            # STEP 3: Concatenate and Generate Palette
            concat_path = tmp_path / "combined.mp4"
            with open(clip_list_path, "w") as f:
                for c in rendered_clips:
                    f.write(f"file '{c.name}'\n")

            # Stitch
            subprocess.run([
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-f", "concat", "-safe", "0", "-i", str(clip_list_path),
                "-c", "copy", str(concat_path)
            ], check=True)

            # High Quality Palette Generation
            palette_path = tmp_path / "palette.png"
            subprocess.run([
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-i", str(concat_path),
                "-vf", f"fps={self.fps},palettegen",
                str(palette_path)
            ], check=True)

            # Final GIF Output
            subprocess.run([
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-i", str(concat_path), "-i", str(palette_path),
                "-lavfi", f"fps={self.fps} [x]; [x][1:v] paletteuse=dither=floyd_steinberg",
                str(output_path)
            ], check=True)
            
            shutil.copy(concat_path, Path.cwd() / f"{slugify(input_path.name)}.mp4")

        print(f"✨ Created: {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Batch convert image folders into unified cropped GIFs.")
    parser.add_argument("pos_dirs", nargs="*", help="Directories containing PNGs (positional fallback)")
    parser.add_argument("--dirs", "-d", nargs="+", help="Directories containing PNGs (flag)")
    parser.add_argument("--fps", type=int, default=12, help="Frames per second (default: 12)")
    parser.add_argument("--hold", type=float, default=2.0, help="Frame hold duration in seconds (default: 2.0)")
    parser.add_argument("--fade", type=float, default=0.5, help="Crossfade duration in seconds (default: 0.5)")
    
    args = parser.parse_args()

    # Collect inputs from either --dirs flag or positional arguments
    raw_inputs = args.dirs if args.dirs else args.pos_dirs
    if not raw_inputs:
        print("❌ Error: No input directories provided.")
        sys.exit(1)

    # Parse inputs in case a single space-separated string was passed from the TUI
    target_dirs = []
    for item in raw_inputs:
        if " " in item and not Path(item).exists():
            target_dirs.extend(shlex.split(item))
        else:
            target_dirs.append(item)

    app = CyberGif(fps=args.fps, hold=args.hold, fade=args.fade)

    for directory in target_dirs:
        try:
            app.process_directory(directory)
        except Exception as e:
            print(f"❌ Failed to process {directory}: {e}")

if __name__ == "__main__":
    main()