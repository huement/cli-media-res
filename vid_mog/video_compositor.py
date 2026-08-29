#!/usr/bin/env python3
"""Video Layer Compositor for PyWocky.

Blends two video streams (e.g., overlaying lineart over color passes) using
FFmpeg complex filtergraphs with adjustable opacity, blend modes, and
automatic dimension matching.
"""

import argparse
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple


def get_video_dimensions(file_path: Path) -> Tuple[int, int]:
    """Queries video dimensions using ffprobe with safe fallback defaults."""
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
        if len(dims) == 2:
            return int(dims[0]), int(dims[1])
    except Exception:
        pass
    return 1280, 720


def blend_video_layers(
    base_path: Path,
    top_path: Path,
    output_path: Path,
    mode: str = "multiply",
    opacity_percent: int = 20,
    use_gpu: bool = False,
) -> None:
    """Blends top video layer onto base video layer using FFmpeg complex filtergraph.

    Args:
        base_path: Path to the bottom/base video clip.
        top_path: Path to the top/overlay video clip.
        output_path: Destination path for rendered video.
        mode: FFmpeg blend mode ('multiply', 'screen', 'overlay', 'darken', 'lighten', etc.).
        opacity_percent: Top layer opacity percentage (1 to 100).
        use_gpu: Enable Apple VideoToolbox hardware encoder.
    """
    if not base_path.exists():
        raise FileNotFoundError(f"Base layer video not found: {base_path}")
    if not top_path.exists():
        raise FileNotFoundError(f"Top layer video not found: {top_path}")

    width, height = get_video_dimensions(base_path)
    opacity_float = max(0.01, min(1.0, opacity_percent / 100.0))

    print(
        f"🎬 Compositing: '{top_path.name}' ({opacity_percent}% {mode.upper()}) -> '{base_path.name}' ({width}x{height})"
    )

    # Force RGB24 color space during blending pass to ensure color matrix fidelity
    filter_complex = (
        f"[0:v]scale={width}:{height},format=rgb24[base_rgb]; "
        f"[1:v]scale={width}:{height},format=rgb24[top_rgb]; "
        f"[base_rgb][top_rgb]blend=all_mode='{mode}':all_opacity={opacity_float:.2f},format=yuv420p[outv]"
    )

    vcodec = "h264_videotoolbox" if use_gpu else "libx264"

    cmd: List[str] = [
        "ffmpeg",
        "-y",
        "-nostdin",
        "-i",
        str(base_path),
        "-i",
        str(top_path),
        "-filter_complex",
        filter_complex,
        "-map",
        "[outv]",
        "-map",
        "0:a?",  # Retain audio from base clip if present
        "-c:v",
        vcodec,
        "-c:a",
        "copy",
        "-shortest",
        str(output_path),
    ]

    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        subprocess.run(cmd, check=True)
        print(f"✅ Compositing Complete: {output_path}")
    except subprocess.CalledProcessError as e:
        print(f"❌ Compositing failed: {e}")
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Video Layer Compositor & Blend Engine for PyWocky"
    )
    parser.add_argument(
        "--base",
        "-b",
        required=True,
        help="Base layer video file path (bottom clip)",
    )
    parser.add_argument(
        "--top",
        "-t",
        required=True,
        help="Overlay layer video file path (top clip)",
    )
    parser.add_argument(
        "--output",
        "-o",
        required=False,
        default=None,
        help="Output destination path (auto-generated if omitted)",
    )
    parser.add_argument(
        "--mode",
        "-m",
        choices=[
            "multiply",
            "screen",
            "overlay",
            "darken",
            "lighten",
            "addition",
            "difference",
            "softlight",
            "hardlight",
        ],
        default="multiply",
        help="Blend mode profile",
    )
    parser.add_argument(
        "--opacity",
        "-p",
        type=int,
        default=20,
        help="Top layer opacity percentage (1 to 100)",
    )
    parser.add_argument(
        "--gpu",
        action="store_true",
        help="Enable Apple VideoToolbox GPU hardware acceleration",
    )

    args = parser.parse_args()

    base_file = Path(args.base).resolve()
    top_file = Path(args.top).resolve()

    if args.output:
        output_file = Path(args.output).resolve()
    else:
        out_name = f"{base_file.stem}_blended_{args.mode}_{args.opacity}pct{base_file.suffix}"
        output_file = base_file.parent / out_name

    blend_video_layers(
        base_path=base_file,
        top_path=top_file,
        output_path=output_file,
        mode=args.mode,
        opacity_percent=args.opacity,
        use_gpu=args.gpu,
    )


if __name__ == "__main__":
    main()