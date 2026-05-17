import os
import argparse
import subprocess
import sys

def detect_best_gpu_encoder():
    """Interrogates FFmpeg directly to see which hardware encoders are compiled and available."""
    try:
        # Run 'ffmpeg -encoders' and capture the text output
        result = subprocess.run(['ffmpeg', '-encoders'], capture_output=True, text=True, check=True)
        
        if 'h264_videotoolbox' in result.stdout:
            return 'h264_videotoolbox'
        if 'h264_nvenc' in result.stdout:
            return 'h264_nvenc'
        if 'h264_amf' in result.stdout:
            return 'h264_amf'
        if 'h264_vaapi' in result.stdout:
            return 'h264_vaapi'
    except Exception:
        # If the ffmpeg command fails for any reason, fall back to basic OS guessing
        pass
    
    # Emergency fallback strategy
    return 'h264_videotoolbox' if sys.platform == 'darwin' else 'h264_nvenc'

def loop_video(args):
    # Smart Naming Logic
    if args.output is None:
        base_dir = os.path.dirname(args.input)
        filename = os.path.basename(args.input)
        name, ext = os.path.splitext(filename)
        
        if args.mode == 'boomerang':
            suffix = "_boomerang"
        else:
            suffix = f"_loop_x{args.count}"
            
        args.output = os.path.join(base_dir, f"{name}{suffix}{ext}")

    # Resolve encoder choice dynamically
    if args.gpu:
        chosen_encoder = detect_best_gpu_encoder()
        print(f"🎮 Hardware Acceleration Active: Automatically selected '{chosen_encoder}'")
    else:
        chosen_encoder = 'libx264'

    # Build the FFmpeg command
    cmd = ['ffmpeg', '-y']

    if args.mode == 'repeat':
        cmd.extend(['-stream_loop', str(args.count - 1), '-i', args.input])
        cmd.extend(['-c:v', chosen_encoder, '-b:v', '12M'])
        cmd.extend(['-c:a', 'copy'])

    elif args.mode == 'boomerang':
        cmd.extend(['-i', args.input])
        
        # Filter complex for reversing and merging
        filter_str = "[0:v]reverse[rev];[0:v][rev]concat=n=2:v=1[v]"
        cmd.extend(['-filter_complex', filter_str, '-map', '[v]'])
        cmd.extend(['-c:v', chosen_encoder])
        cmd.extend(['-an']) 

    # Shared output configuration
    cmd.extend(['-pix_fmt', 'yuv420p', args.output])

    print(f"🚀 Processing loop using mode: '{args.mode}'...")
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        print(f"✨ Success: {args.output}")
    except subprocess.CalledProcessError as e:
        print(f"❌ FFmpeg Error:\n{e.stderr.decode()}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="FFmpeg Video Looper Script")
    parser.add_argument('--input', required=True, help="Path to the input video clip")
    parser.add_argument('--output', required=False, default=None, help="Path to the output video")
    parser.add_argument('--mode', choices=['repeat', 'boomerang'], default='repeat', help="Type of loop")
    parser.add_argument('--count', type=int, default=3, help="Number of times to repeat")
    parser.add_argument('--gpu', action='store_true', help="Use hardware acceleration for encoding")

    args = parser.parse_args()
    loop_video(args)