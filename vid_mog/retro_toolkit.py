#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

# Add the script's directory to Python's module lookup path
SCRIPT_DIR = Path(__file__).parent.resolve()
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import ffmpeg_utils as utils


def process_video(file_path: Path, output_dir: Path, args):
    info = utils.get_video_info(file_path)
    print(f"\n🎬 Applying FX: {file_path.name} ({info['width']}px wide)")

    name_suffix = ""
    v_filters = []
    a_args = ["-c:a", "copy"]

    is_lut_active = bool(args.lut and Path(args.lut).exists())
    v_fmt_filters, v_args = utils.get_encoder_config(
        args.bitrate, is_10bit=is_lut_active
    )
    v_filters.extend(v_fmt_filters)

    if is_lut_active:
        print("    -> 💎 10-bit color workflow activated for LUT processing.")

    # 1. Motion FX
    if args.slowsmooth:
        print("    -> Applying Ultra-Smooth Motion Interpolation (50% Speed)...")
        v_filters.append(
            "setpts=2*PTS,minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:vsbmc=1"
        )
        a_args = ["-c:a", "aac", "-af", "atempo=0.5"]
        name_suffix += "-slowsmooth"
    elif args.ghosting:
        print("    -> Applying Dreamy Frame Blending / Light Trails (50% Speed)...")
        v_filters.append("setpts=2*PTS,minterpolate=fps=60:mi_mode=blend")
        a_args = ["-c:a", "aac", "-af", "atempo=0.5"]
        name_suffix += "-ghosting"

    # 2. Configurable Visual FX (Converts 0 - 100 input down to 0.0 - 1.0)
    if args.crt > 0:
        crt_val = min(max(args.crt / 100.0, 0.0), 1.0)
        opacity = crt_val * 0.6
        print(f"    -> Applying CRT Scanlines (Intensity: {crt_val:.2f})")
        v_filters.append(f"drawgrid=w=0:h=4:t=1:c=black@{opacity:.2f}")
        name_suffix += f"-crt{args.crt}"

    if args.grain > 0:
        grain_val = min(max(args.grain / 100.0, 0.0), 1.0)
        strength = int(grain_val * 60)
        print(f"    -> Applying Film Grain (Intensity: {grain_val:.2f})")
        v_filters.append(f"noise=alls={strength}:allf=t+u")
        name_suffix += f"-grain{args.grain}"

    if args.vignette > 0:
        vig_val = min(max(args.vignette / 100.0, 0.0), 1.0)
        angle = vig_val * 1.2
        print(f"    -> Applying Vignette (Intensity: {vig_val:.2f})")
        v_filters.append(f"vignette=angle={angle:.2f}")
        name_suffix += f"-vignette{args.vignette}"

    if args.rgb_shift > 0:
        shift_val = min(max(args.rgb_shift / 100.0, 0.0), 1.0)
        pixels = int(shift_val * 15)
        print(f"    -> Applying RGB Shift (Intensity: {shift_val:.2f}, {pixels}px)")
        v_filters.append(
            f"rgbashift=rh={pixels}:bh={-pixels}:rv={pixels // 2}:bv={-pixels // 2}"
        )
        name_suffix += f"-rgbshift{args.rgb_shift}"

    # 3. Stylistic Presets
    if args.bloom:
        v_filters.append(
            "split[a][b];[b]gblur=sigma=10[b];[a][b]blend=all_mode=addition:all_opacity=0.7"
        )
        name_suffix += "-bloom"
    if args.twinkle:
        v_filters.append("geq=lum='p(X,Y)*(1+0.15*sin(2*PI*T*1.5))'")
        name_suffix += "-twinkle"
    if args.crush:
        v_filters.append("curves=all='0/0 0.1/0 1/1'")
        name_suffix += "-crush"

    # 4. Color LUT
    if is_lut_active:
        lut_path_str = str(Path(args.lut).resolve()).replace("\\", "/")
        v_filters.append(f"lut3d=file='{lut_path_str}'")
        name_suffix += "-lut"

    if not name_suffix:
        name_suffix = "-retro"

    out_name = f"{utils.slugify(file_path.stem)}{name_suffix}.mp4"
    output_path = output_dir / out_name

    success = utils.run_ffmpeg(file_path, output_path, v_filters, v_args, a_args)
    if success:
        print(f"✅ Finished: {output_path.name}")
    else:
        print(f"❌ Error processing {file_path.name}")


def main():
    parser = argparse.ArgumentParser(
        description="Retro Toolkit (Visual Effects, Retro Filters, Motion)"
    )
    parser.add_argument(
        "--input", "-i", required=True, help="Input file or folder path"
    )
    parser.add_argument("--output", "-o", help="Output directory path")
    parser.add_argument("--bitrate", "-b", default="2000k", help="Target video bitrate")

    # Color & FX
    parser.add_argument("--lut", "-l", help="Path to .cube LUT file")
    parser.add_argument(
        "--crt",
        type=int,
        default=0,
        help="CRT scanlines intensity (0 - 100)",
    )
    parser.add_argument(
        "--grain",
        type=int,
        default=0,
        help="Film grain intensity (0 - 100)",
    )
    parser.add_argument(
        "--vignette",
        type=int,
        default=0,
        help="Vignette darkening (0 - 100)",
    )
    parser.add_argument(
        "--rgb-shift",
        type=int,
        default=0,
        help="RGB Chromatic Aberration (0 - 100)",
    )

    # Presets
    parser.add_argument("--bloom", action="store_true", help="Soft bloom glow effect")
    parser.add_argument("--twinkle", action="store_true", help="Luminance pulse effect")
    parser.add_argument("--crush", action="store_true", help="Crush deep blacks")

    # Motion
    parser.add_argument(
        "--slowsmooth",
        action="store_true",
        help="50% speed motion interpolation",
    )
    parser.add_argument(
        "--ghosting", action="store_true", help="50% speed frame blending"
    )

    args = parser.parse_args()

    utils.process_input(
        args.input,
        args.output,
        lambda inp, out_dir: process_video(inp, out_dir, args),
    )


if __name__ == "__main__":
    main()
