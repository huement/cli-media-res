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
from PIL import Image, ImageOps


def slugify(text):
    """Converts 'My Folder Name!' into 'my-folder-name'"""
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


class CyberGif:
    def __init__(self, fps=12, hold=2.0, fade=0.5, width=None, height=None):
        self.fps = fps
        self.hold = hold
        self.fade = fade
        self.total_dur = hold + (fade * 2)
        self.fade_out_start = hold + fade
        self.width = width
        self.height = height

    def get_image_dimensions(self, img_path):
        """Uses ffprobe to extract the width and height of an image."""
        cmd = [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "csv=s=x:p=0",
            str(img_path),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        dimensions = result.stdout.strip().split("x")
        return int(dimensions[0]), int(dimensions[1])

    def find_minimum_dimensions(self, images):
        """Scans all images to find the absolute smallest bounding box."""
        min_w = float("inf")
        min_h = float("inf")

        print("🔍 Analyzing image resolutions...")
        for img in images:
            w, h = self.get_image_dimensions(img)
            if w < min_w:
                min_w = w
            if h < min_h:
                min_h = h

        return min_w, min_h

    def process_directory(self, input_dir, output_name, output_path):
        input_path = Path(input_dir).resolve()

        if not input_path.is_dir():
            print(f"❌ Skipping: '{input_dir}' is not a valid directory.")
            return

        # Gather images
        images = sorted(
            [f for f in input_path.glob("*.png") if not f.name.startswith(".")]
        )
        if not images:
            print(f"⚠️  No PNGs found in {input_path.name}")
            return

        # STEP 1: Determine target size (Fallback to minimum dimensions if unspecified)
        if not self.width or not self.height:
            auto_w, auto_h = self.find_minimum_dimensions(images)
            target_w = self.width if self.width else auto_w
            target_h = self.height if self.height else auto_h
        else:
            target_w, target_h = self.width, self.height

        print(f"📐 Target Resolution: {target_w}x{target_h}")
        print(
            f"🎬 Processing '{input_path.name}' -> {output_name} ({len(images)} frames)"
        )

        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            clip_list_path = tmp_path / "clips.txt"

            # STEP 2: Smart crop images and generate individual clips with fades
            rendered_clips = []
            for i, img in enumerate(images):
                cropped_img_path = tmp_path / f"frame_{i:03d}.png"
                with Image.open(img) as pillow_img:
                    smart_cropped = ImageOps.fit(
                        pillow_img,
                        (target_w, target_h),
                        method=Image.Resampling.LANCZOS,
                        centering=(0.5, 0.5),
                    )
                    smart_cropped.save(cropped_img_path)

                clip_path = tmp_path / f"clip_{i:03d}.mp4"

                filter_str = (
                    f"setsar=1,"
                    f"fade=t=in:st=0:d={self.fade},"
                    f"fade=t=out:st={self.fade_out_start}:d={self.fade}"
                )

                cmd = [
                    "ffmpeg",
                    "-y",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-loop",
                    "1",
                    "-i",
                    str(cropped_img_path),
                    "-t",
                    str(self.total_dur),
                    "-vf",
                    filter_str,
                    "-c:v",
                    "libx264",
                    "-pix_fmt",
                    "yuv420p",
                    "-preset",
                    "ultrafast",
                    str(clip_path),
                ]

                subprocess.run(cmd, check=True)
                rendered_clips.append(clip_path)

            # STEP 3: Concatenate and Generate Palette
            concat_path = tmp_path / "combined.mp4"
            with open(clip_list_path, "w") as f:
                for c in rendered_clips:
                    f.write(f"file '{c.name}'\n")

            # Stitch
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-f",
                    "concat",
                    "-safe",
                    "0",
                    "-i",
                    str(clip_list_path),
                    "-c",
                    "copy",
                    str(concat_path),
                ],
                check=True,
            )

            # High Quality Palette Generation
            palette_path = tmp_path / "palette.png"
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-i",
                    str(concat_path),
                    "-vf",
                    f"fps={self.fps},palettegen",
                    str(palette_path),
                ],
                check=True,
            )

            # Ensure parent output directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)

            # Final GIF Output
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-i",
                    str(concat_path),
                    "-i",
                    str(palette_path),
                    "-lavfi",
                    f"fps={self.fps} [x]; [x][1:v] paletteuse=dither=floyd_steinberg",
                    str(output_path),
                ],
                check=True,
            )

            # Copy matching MP4 to output destination
            shutil.copy(concat_path, output_path.with_suffix(".mp4"))

        print(f"✨ Created: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Batch convert image folders into unified cropped GIFs."
    )
    parser.add_argument(
        "pos_dirs", nargs="*", help="Directories containing PNGs (positional fallback)"
    )
    parser.add_argument(
        "--dirs", "-d", nargs="+", help="Directories containing PNGs (flag)"
    )
    parser.add_argument(
        "--output",
        "-o",
        nargs="+",
        help="Optional destination path or filename for the final output",
    )
    parser.add_argument(
        "--width", type=int, default=None, help="Output width in pixels (default: auto)"
    )
    parser.add_argument(
        "--height",
        type=int,
        default=None,
        help="Output height in pixels (default: auto)",
    )
    parser.add_argument(
        "--fps", type=int, default=12, help="Frames per second (default: 12)"
    )
    parser.add_argument(
        "--hold",
        type=int,
        default=20,
        help="Frame hold duration in seconds (default: 20)",
    )
    parser.add_argument(
        "--fade",
        type=int,
        default=5,
        help="Crossfade duration in seconds (default: 5)",
    )

    args = parser.parse_args()

    raw_inputs = args.dirs if args.dirs else args.pos_dirs
    if not raw_inputs:
        print("❌ Error: No input directories provided.")
        sys.exit(1)

    target_dirs = []
    for item in raw_inputs:
        if " " in item and not Path(item).exists():
            target_dirs.extend(shlex.split(item))
        else:
            target_dirs.append(item)

    app = CyberGif(
        fps=args.fps,
        hold=args.hold * 0.1,
        fade=args.fade * 0.1,
        width=args.width,
        height=args.height,
    )

    # Process custom output argument safely
    raw_output = " ".join(args.output) if args.output else None

    for directory in target_dirs:
        try:
            dir_path = Path(directory).resolve()

            if raw_output:
                custom_path = Path(raw_output).resolve()
                if custom_path.is_dir() or raw_output.endswith(os.sep):
                    output_name = f"{slugify(dir_path.name)}.gif"
                    output_path = custom_path / output_name
                else:
                    output_name = custom_path.name
                    output_path = custom_path
            else:
                output_name = f"{slugify(dir_path.name)}.gif"
                output_path = Path.cwd() / output_name

            app.process_directory(directory, output_name, output_path)
        except Exception as e:
            print(f"❌ Failed to process {directory}: {e}")


if __name__ == "__main__":
    main()
