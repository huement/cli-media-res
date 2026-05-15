import subprocess
import os
import sys
import tempfile
import re
import argparse
from pathlib import Path

def slugify(text):
    """Converts 'My Folder Name!' into 'my-folder-name'"""
    text = text.lower()
    text = re.sub(r'[^a-z0-9]+', '-', text)
    return text.strip('-')

class CyberGif:
    def __init__(self, width=1200, height=676, fps=12, hold=2.0, fade=0.5):
        self.width = width
        self.height = height
        self.fps = fps
        self.hold = hold
        self.fade = fade
        self.total_dur = hold + (fade * 2)
        self.fade_out_start = hold + fade

    def process_directory(self, input_dir):
        input_path = Path(input_dir).resolve()
        
        if not input_path.is_dir():
            print(f"❌ Skipping: {input_dir} is not a directory.")
            return

        # Generate slugified name from directory name
        output_name = f"{slugify(input_path.name)}.gif"
        output_path = Path.cwd() / output_name

        images = sorted([f for f in input_path.glob("*.png") if not f.name.startswith('.')])
        if not images:
            print(f"⚠️  No PNGs found in {input_path.name}")
            return

        print(f"🎬 Processing '{input_path.name}' -> {output_name} ({len(images)} frames)")

        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            clip_list_path = tmp_path / "clips.txt"
            
            # 1. Generate individual clips (needed for the complex fade logic)
            # We keep this part from your original script because cross-fading 
            # via filter_complex with an arbitrary number of images is a nightmare.
            rendered_clips = []
            for i, img in enumerate(images):
                clip_path = tmp_path / f"clip_{i:03d}.mp4"
                
                filter_str = (
                    f"scale={self.width}:{self.height}:force_original_aspect_ratio=decrease,"
                    f"pad={self.width}:{self.height}:(ow-iw)/2:(oh-ih)/2:black,"
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

            # 2. Concatenate and Generate Palette
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

        print(f"✨ Created: {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Batch convert image folders into Cyberpunk-style GIFs.")
    parser.add_argument("dirs", nargs="+", help="One or more directories containing PNGs")
    parser.add_argument("--fps", type=int, default=12, help="Frames per second (default: 12)")
    parser.add_argument("--width", type=int, default=1200, help="Output width (default: 1200)")
    
    args = parser.parse_args()

    app = CyberGif(width=args.width, fps=args.fps)

    for directory in args.dirs:
        try:
            app.process_directory(directory)
        except Exception as e:
            print(f"❌ Failed to process {directory}: {e}")

if __name__ == "__main__":
    main()