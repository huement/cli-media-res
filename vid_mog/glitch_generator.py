#!/usr/bin/env python3
"""Experimental Databending & Video Glitch Generator for PyWocky.

Applies artistic video corruption, chromatic aberration, motion vector rendering,
and optical flow distortion via FFmpeg complex filtergraphs.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg"}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".avi"}


def slugify(text: str) -> str:
    """Converts input filenames to clean, URL-safe slugs."""
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def get_video_dimensions(file_path: Path) -> Tuple[int, int]:
    """Queries input media dimensions via ffprobe with safe fallback defaults."""
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
        str(file_path),
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        dims = result.stdout.strip().split("x")
        return int(dims[0]), int(dims[1])
    except Exception:
        return 1280, 720


def build_glitch_pipeline(
    file_path: Path,
    mode: str,
    width: int,
    height: int,
    is_image: bool,
    use_gpu: bool,
) -> Tuple[List[str], str, List[str], List[str]]:
    """Builds the FFmpeg CLI arguments, video filters, and encoder parameters for the selected glitch engine."""
    ffmpeg_inputs: List[str] = []
    video_args: List[str] = (
        ["-c:v", "h264_videotoolbox", "-pix_fmt", "yuv420p"]
        if use_gpu
        else ["-c:v", "libx264", "-pix_fmt", "yuv420p"]
    )
    audio_args: List[str] = ["-c:a", "copy"]
    video_filter: str = ""

    # Loop static image for temporal glitch modes
    if is_image and mode in ("vectors", "stack", "echo", "morph"):
        ffmpeg_inputs.extend(["-loop", "1", "-t", "5", "-i", str(file_path)])
    else:
        ffmpeg_inputs.extend(["-i", str(file_path)])

    if mode == "aberration":
        video_filter = (
            f"split=3[r][g][b]; "
            f"nullsrc=size={width}x{height}[b1]; nullsrc=size={width}x{height}[b2]; nullsrc=size={width}x{height}[b3]; "
            f"[r]lutrgb=g=0:b=0[red]; [g]lutrgb=r=0:b=0[green]; [b]lutrgb=r=0:g=0[blue]; "
            f"[b1][red]overlay=x=12:shortest=1,format=rgb24[x]; "
            f"[b2][green]overlay=x=0:shortest=1,format=rgb24[y]; "
            f"[b3][blue]overlay=y=8:shortest=1,format=rgb24[z]; "
            f"[x][y]blend=all_mode='addition'[xy]; "
            f"[xy][z]blend=all_mode='addition'[xyz]; "
            f"[xyz]crop={width}-20:{height}-20:10:10,scale={width}:{height}"
        )

    elif mode == "vectors":
        ffmpeg_inputs = ["-flags2", "+export_mvs"] + ffmpeg_inputs
        video_filter = (
            "split[original],codecview=mv=pf+bf+bb[vectors]; "
            "[vectors][original]blend=all_mode=difference128, "
            "eq=contrast=8:brightness=-0.2"
        )
        audio_args = ["-an"]

    elif mode == "stack":
        video_filter = (
            f"scale=-2:{height}, "
            "tblend=all_mode=difference128,tblend=all_mode=difference128,tblend=all_mode=difference128,spp=4:10,tblend=all_mode=average, "
            "tblend=all_mode=difference128,tblend=all_mode=difference128,tblend=all_mode=difference128,spp=4:10,tblend=all_mode=average, "
            "tblend=all_mode=difference128,tblend=all_mode=difference128,tblend=all_mode=difference128"
        )

    elif mode == "echo":
        ffmpeg_inputs = [
            "-i",
            str(file_path),
            "-ss",
            "00:00:00.20",
            "-i",
            str(file_path),
            "-ss",
            "00:00:00.40",
            "-i",
            str(file_path),
        ]
        video_filter = (
            "[0][1]blend=all_mode=lighten[a];"
            "[1][2]blend=all_mode=lighten[b];"
            "[a][b]blend=all_mode=lighten[p];"
            "[0][p]blend=all_mode=lighten"
        )

    elif mode == "databend":
        ffmpeg_inputs = [
            "-i",
            str(file_path),
            "-i",
            str(file_path),
            "-i",
            str(file_path),
        ]
        video_filter = "[0][1][2]displace=edge=wrap[middle];[middle]stereo3d=ar"
        video_args = ["-c:v", "libx265", "-crf", "42", "-b:v", "15k"]

    elif mode == "morph":
        video_filter = "setpts=62.5*PTS,minterpolate=fps=25:mb_size=16:search_param=400:vsbmc=0:scd=none:mc_mode=aobmc:me_mode=bilat:me=umh"
        audio_args = ["-an"]

    return ffmpeg_inputs, video_filter, video_args, audio_args


def process_glitch_target(
    target_file: Path,
    output_dir: Path,
    mode: str,
    use_gpu: bool,
) -> None:
    """Executes the glitch rendering pipeline for a single target media file."""
    ext_lower = target_file.suffix.lower()
    is_image = ext_lower in IMAGE_EXTENSIONS

    if is_image and mode == "echo":
        print(f"⚠️ Skipping Echo mode on static image: {target_file.name}")
        return

    width, height = get_video_dimensions(target_file)
    print(
        f"🎬 Processing: {target_file.name} ({width}x{height} | Mode: {mode})"
    )

    ffmpeg_inputs, video_filter, video_args, audio_args = build_glitch_pipeline(
        target_file, mode, width, height, is_image, use_gpu
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    slug_name = slugify(target_file.stem)

    if is_image and mode == "aberration":
        output_file = output_dir / f"{slug_name}_glitch_{mode}.png"
        video_args = ["-c:v", "png"]
        audio_args = []
    else:
        output_file = output_dir / f"{slug_name}_glitch_{mode}.mp4"

    cmd = ["ffmpeg", "-nostdin", "-y"] + ffmpeg_inputs
    if video_filter:
        cmd.extend(["-filter_complex", video_filter])
    cmd.extend(video_args + audio_args + [str(output_file)])

    try:
        subprocess.run(cmd, check=True)
        print(f"✅ Glitch Complete: {output_file}")
    except subprocess.CalledProcessError as e:
        print(f"❌ Render failed for {target_file.name}: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Databending & Video Glitch Generator for PyWocky"
    )
    parser.add_argument(
        "--input",
        "-i",
        required=True,
        help="Input media file or folder directory",
    )
    parser.add_argument(
        "--output",
        "-o",
        help="Destination directory for output files",
    )
    parser.add_argument(
        "--mode",
        "-m",
        choices=["aberration", "vectors", "stack", "echo", "databend", "morph"],
        default="aberration",
        help="Glitch processing mode",
    )
    parser.add_argument(
        "--gpu",
        action="store_true",
        help="Enable Apple VideoToolbox hardware acceleration",
    )

    args = parser.parse_args()
    input_path = Path(args.input).resolve()

    if not input_path.exists():
        print(f"❌ Error: Input target not found: {input_path}")
        sys.exit(1)

    output_dir = (
        Path(args.output).resolve()
        if args.output
        else (input_path if input_path.is_dir() else input_path.parent)
    )

    valid_extensions = IMAGE_EXTENSIONS | VIDEO_EXTENSIONS

    if input_path.is_file():
        if input_path.suffix.lower() in valid_extensions:
            process_glitch_target(input_path, output_dir, args.mode, args.gpu)
        else:
            print(f"❌ Error: Unsupported file format {input_path.suffix}")
    elif input_path.is_dir():
        targets = [
            p
            for p in input_path.iterdir()
            if p.is_file() and p.suffix.lower() in valid_extensions
        ]
        if not targets:
            print(f"⚠️ No compatible image or video files found in {input_path}")
            sys.exit(0)

        for target in targets:
            process_glitch_target(target, output_dir, args.mode, args.gpu)


if __name__ == "__main__":
    main()