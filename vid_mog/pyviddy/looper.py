#!/usr/bin/env python3
import argparse
import subprocess
import json
import sys
import os

def get_video_duration(input_file):
    """Query file metadata to discover exact timeline duration properties."""
    cmd = [
        'ffprobe', '-v', 'error', 
        '-show_entries', 'format=duration', 
        '-of', 'json', input_file
    ]
    try:
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        data = json.loads(result.stdout)
        return float(data['format']['duration'])
    except (subprocess.CalledProcessError, KeyError, ValueError) as e:
        print(f"❌ Core Error: Failed to extract video properties via ffprobe: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Cyberpunk Video Looper Engine Backend")
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--mode', default='repeat', choices=['repeat', 'boomerang'])
    parser.add_argument('--count', type=int, default=3)
    parser.add_argument('--fade', type=float, default=1.0)
    parser.add_argument('--gpu', action='store_true')
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"❌ Error: Input file path does not exist: {args.input}", file=sys.stderr)
        sys.exit(1)

    total_duration = get_video_duration(args.input)
    fade_len = args.fade

    if fade_len >= total_duration:
        fade_len = total_duration / 4.0
        print(f"⚠️ Warning: Fade window exceeded clip limits. Downscaled to: {fade_len}s")

    # VideoToolbox handles both Apple Silicon and Intel AMD cards via macOS drivers!
    vcodec = 'h264_videotoolbox' if args.gpu else 'libx264'

    # Build the structural FFmpeg complex filter graph string
    filter_graph = ""

    if args.mode == 'repeat':
        tail_start = total_duration - fade_len
        filter_graph += f"[0:v]trim=start={tail_start}:end={total_duration},setpts=PTS-STARTPTS[tail]; "
        filter_graph += f"[0:v]trim=start=0:end={tail_start},setpts=PTS-STARTPTS[main]; "
        filter_graph += f"[tail][main]xfade=transition=fade:duration={fade_len}:offset=0[base_loop]; "
    else:
        filter_graph += "[0:v]split=2[f1][f2]; [f2]reverse,setpts=PTS-STARTPTS[r1]; [f1][r1]concat=n=2:v=1:a=0[base_loop]; "

    if args.count > 1:
        splits = "".join([f"[split_{i}]" for i in range(args.count)])
        filter_graph += f"[base_loop]split={args.count}{splits}; "
        
        inputs = "".join([f"[split_{i}]" for i in range(args.count)])
        filter_graph += f"{inputs}concat=n={args.count}:v=1:a=0[final_out]"
    else:
        filter_graph += "[base_loop]null[final_out]"

    ffmpeg_cmd = [
        'ffmpeg', '-y', '-v', 'error', '-stats',
        '-i', args.input,
        '-filter_complex', filter_graph,
        '-map', '[final_out]',
        '-c:v', vcodec,
        '-pix_fmt', 'yuv420p',
    ]

    # 🚨 AMD VIDEOTOOLBOX OPTIMIZATION: Forced bitrate controls prevent compression artifacts
    if args.gpu:
        ffmpeg_cmd += [
            '-b:v', '8000k',       # Target bitrate (8 Mbps keeps 1080p/4K pristine)
            '-maxrate', '12000k',   # Allows bitrate spikes for high-motion frames
            '-bufsize', '8000k',
            '-realtime', '1'       # Tells VideoToolbox to prioritize execution speed
        ]

    ffmpeg_cmd.append(args.output)

    print(f"🧬 Blending video pixels via complex filter graph engine...")
    try:
        subprocess.run(ffmpeg_cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Processing Engine Crash: FFmpeg failed to compile loop layout: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()