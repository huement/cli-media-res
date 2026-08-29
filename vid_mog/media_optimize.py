#!/usr/bin/env python3
import argparse
import re
from pathlib import Path
import ffmpeg_utils as utils


def process_video(file_path: Path, output_dir: Path, args):
    info = utils.get_video_info(file_path)
    width = info["width"]
    print(f"\n🎬 Optimizing Media: {file_path.name} ({width}px wide)")

    resized = False
    name_suffix = ""
    v_filters, v_args = utils.get_encoder_config(args.bitrate)
    a_args = ["-c:a", "copy"]

    # 1. Smart Upscaling
    opt_target = (args.optimize or "none").lower()
    if opt_target not in ("none", "false"):
        v_filters.append("hqdn3d=0.5:0.5:3:3")
        target_map = {
            "720p": (1280, 720),
            "1080p": (1920, 1080),
            "1440p": (2560, 1440),
            "4k": (3840, 2160),
        }
        if opt_target in target_map:
            target_w, target_h = target_map[opt_target]
            if 0 < width < target_w:
                print(f"    -> Upscaling to {opt_target}...")
                v_filters.append(
                    f"scale={target_w}:{target_h}:flags=lanczos,unsharp=3:3:0.5:3:3:0.5"
                )
                name_suffix += f"-{opt_target}"
                resized = True
            else:
                print(f"    -> Skipping upscale (Width {width}px >= {target_w}px).")
                name_suffix += "-orig"

    # 2. Downscaling Pipeline
    if args.downscale:
        ds_size = re.sub(r"\D", "", args.downscale) or "480"
        print(f"    -> Downscaling to {ds_size}p...")
        v_filters.append(f"scale=-2:{ds_size}")
        resized = True
        name_suffix += f"-{ds_size}"

    # 3. Watermarking
    watermark_info = None
    if args.watermark and Path(args.watermark).exists():
        watermark_info = (args.watermark, args.wm_width)
        name_suffix += "-wm"

    if not name_suffix:
        name_suffix = "-optimized"

    out_name = f"{utils.slugify(file_path.stem)}{name_suffix}.mp4"
    output_path = output_dir / out_name

    success = utils.run_ffmpeg(
        file_path,
        output_path,
        v_filters,
        v_args,
        a_args,
        watermark=watermark_info,
    )

    if success:
        print(f"✅ Finished: {output_path.name}")
        if resized:
            new_info = utils.get_video_info(output_path)
            print(f"📐 Output dimensions: {new_info['width']}x{new_info['height']}")
    else:
        print(f"❌ Error processing {file_path.name}")


def main():
    parser = argparse.ArgumentParser(
        description="Media Optimizer (Resize, Upscale, Downscale, Bitrate, Watermark)"
    )
    parser.add_argument(
        "--input", "-i", required=True, help="Input file or folder path"
    )
    parser.add_argument("--output", "-o", help="Output directory path")
    parser.add_argument("--bitrate", "-b", default="2000k", help="Target video bitrate")
    parser.add_argument(
        "--optimize",
        choices=["none", "720p", "1080p", "1440p", "4k"],
        default="none",
        help="Smart upscale target resolution",
    )
    parser.add_argument(
        "--downscale", "-ds", help="Downscale target height (e.g. 720p, 480)"
    )
    parser.add_argument("--watermark", "-wm", help="Path to watermark image")
    parser.add_argument(
        "--wm-width", "-ww", type=int, default=120, help="Watermark pixel width"
    )

    args = parser.parse_args()

    if args.optimize != "none" and args.downscale:
        print(
            "❌ Error: Cannot use --optimize (upscale) and --downscale simultaneously."
        )
        return

    utils.process_input(
        args.input,
        args.output,
        lambda inp, out_dir: process_video(inp, out_dir, args),
    )


if __name__ == "__main__":
    main()
