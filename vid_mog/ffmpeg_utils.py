#!/usr/bin/env python3
import json
import platform
import re
import subprocess
import sys
from pathlib import Path


def slugify(text: str) -> str:
    """Converts a string into a clean filename slug."""
    text = re.sub(r"[^\w\s-]", "", text).strip().lower()
    return re.sub(r"[-\s]+", "-", text)


def get_video_info(video_path: Path) -> dict:
    """Uses ffprobe to extract stream width and height as JSON."""
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height",
        "-of",
        "json",
        str(video_path),
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(res.stdout)
        streams = data.get("streams", [])
        if streams:
            return {
                "width": streams[0].get("width", 0),
                "height": streams[0].get("height", 0),
            }
    except Exception:
        pass
    return {"width": 0, "height": 0}


def get_encoder_config(
    bitrate: str, is_10bit: bool = False
) -> tuple[list[str], list[str]]:
    """Returns format filters and video encoder args based on architecture and bit-depth."""
    is_arm = platform.machine() == "arm64"

    if is_10bit:
        v_format = ["format=pix_fmts=p010le"]
        v_args = [
            "-c:v",
            "hevc_videotoolbox",
            "-profile:v",
            "main10",
            "-pix_fmt",
            "p010le",
            "-b:v",
            bitrate,
            "-tag:v",
            "hvc1",
        ]
    else:
        v_format = ["format=pix_fmts=yuv420p"]
        if is_arm:
            v_args = [
                "-c:v",
                "hevc_videotoolbox",
                "-b:v",
                bitrate,
                "-pix_fmt",
                "yuv420p",
                "-tag:v",
                "hvc1",
            ]
        else:
            v_args = [
                "-c:v",
                "h264_videotoolbox",
                "-b:v",
                bitrate,
                "-pix_fmt",
                "yuv420p",
            ]

    return v_format, v_args


def run_ffmpeg(
    input_path: Path,
    output_path: Path,
    v_filters: list[str],
    v_args: list[str],
    a_args: list[str],
    watermark: tuple[str, int] = None,
) -> bool:
    """Builds and executes the FFmpeg command."""
    cmd = ["ffmpeg", "-nostdin", "-y", "-i", str(input_path)]
    filter_chain = ",".join(v_filters) if v_filters else "null"

    if watermark and Path(watermark[0]).exists():
        wm_path, wm_width = watermark
        cmd.extend(["-i", str(Path(wm_path).resolve())])
        complex_filter = (
            f"[1:v]scale={wm_width}:-1[wm]; "
            f"[0:v]{filter_chain}[base]; "
            f"[base][wm]overlay=W-w-20:H-h-20"
        )
        cmd.extend(["-filter_complex", complex_filter])
    else:
        cmd.extend(["-filter_complex", filter_chain])

    cmd.extend(v_args)
    cmd.extend(a_args)
    cmd.append(str(output_path))

    res = subprocess.run(cmd)
    return res.returncode == 0


def process_input(input_arg: str, output_arg: str, process_file_fn):
    """Handles folder scanning or single file dispatch."""
    inp = Path(input_arg)
    if not inp.exists():
        print(f"❌ Error: Input path not found: {inp}")
        sys.exit(1)

    out_dir = Path(output_arg) if output_arg else (inp if inp.is_dir() else inp.parent)
    out_dir.mkdir(parents=True, exist_ok=True)

    if inp.is_file():
        process_file_fn(inp, out_dir)
    elif inp.is_dir():
        mp4s = list(inp.glob("*.mp4"))
        print(f"📂 Found {len(mp4s)} MP4 files in {inp}...")
        for mp4 in mp4s:
            process_file_fn(mp4, out_dir)
