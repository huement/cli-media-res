#!/usr/bin/env python3
import os
import sys
import json
import re
import platform
import argparse
import subprocess
from pathlib import Path

def slugify(text: str) -> str:
    """Converts a string into a clean filename slug."""
    text = re.sub(r'[^\w\s-]', '', text).strip().lower()
    return re.sub(r'[-\s]+', '-', text)

def get_video_info(video_path: Path) -> dict:
    """Uses ffprobe to extract stream width and height as JSON."""
    cmd = [
        "ffprobe", "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height",
        "-of", "json",
        str(video_path)
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(res.stdout)
        streams = data.get("streams", [])
        if streams:
            return {"width": streams[0].get("width", 0), "height": streams[0].get("height", 0)}
    except Exception:
        pass
    return {"width": 0, "height": 0}

def process_video(file_path: Path, output_dir: Path, args):
    info = get_video_info(file_path)
    width = info["width"]
    print(f"\n🎬 Analyzing: {file_path.name} ({width}px wide)")

    resized = False
    name_suffix = ""
    v_filters = []
    
    # 1. Base Setup & Codecs
    is_arm = platform.machine() == "arm64"
    is_lut_active = bool(args.lut and Path(args.lut).exists())
    is_downscaling = bool(args.downscale)

    # Professional 10-bit workflow check
    if is_lut_active and not is_downscaling:
        print("    -> 💎 Professional 10-bit color workflow activated for LUT processing.")
        v_filters.append("format=pix_fmts=p010le")
        v_args = ["-c:v", "hevc_videotoolbox", "-profile:v", "main10", "-pix_fmt", "p010le", "-b:v", args.bitrate, "-tag:v", "hvc1"]
    else:
        v_filters.append("format=pix_fmts=yuv420p")
        if is_arm:
            v_args = ["-c:v", "hevc_videotoolbox", "-b:v", args.bitrate, "-pix_fmt", "yuv420p", "-tag:v", "hvc1"]
        else:
            v_args = ["-c:v", "h264_videotoolbox", "-b:v", args.bitrate, "-pix_fmt", "yuv420p"]

    a_args = ["-c:a", "copy"]

    # 2. Smart Optimization (Denoise & Upscale)
    opt_target = (args.optimize or "none").lower()
    if opt_target not in ("none", "false"):
        v_filters.append("hqdn3d=0.5:0.5:3:3")
        target_map = {"720p": (1280, 720), "1080p": (1920, 1080), "1440p": (2560, 1440), "4k": (3840, 2160)}
        
        if opt_target in target_map:
            target_w, target_h = target_map[opt_target]
            if 0 < width < target_w:
                print(f"    -> Upscaling to {opt_target}...")
                v_filters.append(f"scale={target_w}:{target_h}:flags=lanczos,unsharp=3:3:0.5:3:3:0.5")
                name_suffix += f"-{opt_target}"
                resized = True
            else:
                print(f"    -> Skipping upscale (Width {width}px >= {target_w}px).")
                name_suffix += "-orig"

    # 3. Downscaling Pipeline
    if args.downscale:
        ds_size = re.sub(r"\D", "", args.downscale) or "480"
        print(f"    -> Downscaling to {ds_size}p...")
        v_filters.append(f"scale=-2:{ds_size}")
        resized = True
        name_suffix += f"-{ds_size}"

    # 4. Motion Interpolation / Slow Motion
    if args.slowsmooth:
        print("    -> Applying Ultra-Smooth Motion Interpolation (50% Speed)...")
        v_filters.append("setpts=2*PTS,minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:vsbmc=1")
        a_args = ["-c:a", "aac", "-af", "atempo=0.5"]
        name_suffix += "-slowsmooth"
    elif args.ghosting:
        print("    -> Applying Dreamy Frame Blending / Light Trails (50% Speed)...")
        v_filters.append("setpts=2*PTS,minterpolate=fps=60:mi_mode=blend")
        a_args = ["-c:a", "aac", "-af", "atempo=0.5"]
        name_suffix += "-ghosting"

    # 5. Creative FX Pipeline
    if args.bloom:
        v_filters.append("split[a][b];[b]gblur=sigma=10[b];[a][b]blend=all_mode=addition:all_opacity=0.7")
        name_suffix += "-bloom"
    if args.twinkle:
        v_filters.append("geq=lum='p(X,Y)*(1+0.15*sin(2*PI*T*1.5))'")
        name_suffix += "-twinkle"
    if args.aberration:
        v_filters.append("chromashift=cbh=10:cbv=4:crh=-10:crv=-4")
        name_suffix += "-distort"
    if args.crush:
        v_filters.append("curves=all='0/0 0.1/0 1/1'")
        name_suffix += "-crush"
    if args.glitch:
        v_filters.append("rgbashift=rh=3:bh=-3")
        name_suffix += "-glitch"
    if args.grain:
        v_filters.append("noise=alls=8:allf=t")
        name_suffix += "-grain"

    # 6. Color LUT Processing
    if is_lut_active:
        lut_path_str = str(Path(args.lut).resolve()).replace("\\", "/")
        v_filters.append(f"lut3d=file='{lut_path_str}'")
        name_suffix += "-lut"

    if not name_suffix:
        name_suffix = "-processed"

    out_name = f"{slugify(file_path.stem)}{name_suffix}.mp4"
    output_path = output_dir / out_name

    # 7. Build Execution Command
    filter_chain = ",".join(v_filters)
    cmd = ["ffmpeg", "-nostdin", "-y", "-i", str(file_path)]

    if args.watermark and Path(args.watermark).exists():
        wm_path = str(Path(args.watermark).resolve())
        cmd.extend(["-i", wm_path])
        complex_filter = f"[1:v]scale={args.wm_width}:-1[wm]; [0:v]{filter_chain}[base]; [base][wm]overlay=W-w-20:H-h-20"
        cmd.extend(["-filter_complex", complex_filter])
    else:
        cmd.extend(["-filter_complex", filter_chain])

    cmd.extend(v_args)
    cmd.extend(a_args)
    cmd.append(str(output_path))

    # Execute
    res = subprocess.run(cmd)
    if res.returncode == 0:
        print(f"✅ Finished: {output_path.name}")
        if resized:
            new_info = get_video_info(output_path)
            print(f"📐 Output dimensions: {new_info['width']}x{new_info['height']}")
    else:
        print(f"❌ Error processing {file_path.name}")

def main():
    parser = argparse.ArgumentParser(description="Ultimate Video Toolkit")
    parser.add_argument("--input", "-i", required=True, help="Input file or folder path")
    parser.add_argument("--output", "-o", help="Output directory path")
    parser.add_argument("--bitrate", "-b", default="2000k", help="Video bitrate")
    parser.add_argument("--optimize", choices=["none", "720p", "1080p", "1440p", "4k"], default="none")
    parser.add_argument("--downscale", "-ds", help="Downscale height proportion (e.g. 720p, 480)")
    parser.add_argument("--lut", "-l", help="Path to .cube LUT file")
    parser.add_argument("--watermark", "-wm", help="Path to watermark image")
    parser.add_argument("--wm-width", "-ww", type=int, default=120)
    parser.add_argument("--slowsmooth", action="store_true")
    parser.add_argument("--ghosting", action="store_true")
    parser.add_argument("--bloom", action="store_true")
    parser.add_argument("--twinkle", action="store_true")
    parser.add_argument("--aberration", action="store_true")
    parser.add_argument("--crush", action="store_true")
    parser.add_argument("--glitch", action="store_true")
    parser.add_argument("--grain", action="store_true")

    args = parser.parse_args()

    if args.optimize != "none" and args.downscale:
        print("❌ Error: Cannot use --optimize (upscale) and --downscale simultaneously.")
        sys.exit(1)

    inp = Path(args.input)
    if not inp.exists():
        print(f"❌ Error: Input path not found: {inp}")
        sys.exit(1)

    out_dir = Path(args.output) if args.output else (inp if inp.is_dir() else inp.parent)
    out_dir.mkdir(parents=True, exist_ok=True)

    if inp.is_file():
        process_video(inp, out_dir, args)
    elif inp.is_dir():
        mp4s = list(inp.glob("*.mp4"))
        print(f"📂 Found {len(mp4s)} MP4 files in {inp}...")
        for mp4 in mp4s:
            process_video(mp4, out_dir, args)

if __name__ == "__main__":
    main()