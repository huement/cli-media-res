# CLI Media Resource Optimizer
A collection of high-performance Bash scripts for automating video optimization, upscaling, and stylistic processing on macOS using hardware acceleration.

# 🚀 Overview
This repository provides a command-line workflow for taking raw video files (like stock footage) and transforming them into optimized, web-ready, or cinematically graded assets. It leverages **FFmpeg** with **Apple Videotoolbox** for high-speed encoding on AMD and Apple Silicon GPUs.

# 📁 Repository Structure
* **/ (Root)**: Contains the primary execution scripts and core libraries.
* **bash-args.sh**: A custom library for handling complex command-line arguments, flags, and help menus.
* **vidpro.sh**: The main "all-in-one" optimizer. It handles resolution detection, upscaling, slugification, and optional effects.
* **upscaler-amd.sh**: A legacy standalone script for basic 1080p Lanczos upscaling.
* **upscale-cine-amd.sh**: A legacy script focused on cinematic grading via LUTs and denoising.

⠀🛠 Requirements
* **macOS**: Optimized for systems with AMD GPUs or Apple Silicon.
* **Modern Bash (v4.0+)**: Required for associative array support in the arguments library.
  * *Note: macOS default /bin/bash is version 3.2. Use brew install bash to update.*
* **FFmpeg**: Must be compiled with --enable-videotoolbox.
* **ffprobe**: Included with FFmpeg, used for resolution detection.

⠀💻 Usage: vidpro.sh
The vidpro.sh script is the primary tool. It is "smart"—it will upscale lower-resolution footage to 1080p while skipping the scale process for 4K files to preserve quality.

### Basic Commands

**Process a folder and output elsewhere:**
Bash
```
./vidpro.sh --input ~/Movies/Source --output ~/Movies/Optimized
```

**Apply Cinematic LUT and Film Grain:**
Bash
```
./vidpro.sh --lut ./CineGrade.cube --grain
```

**Apply Glitch Effect and Watermark:**
Bash
```
./vidpro.sh --glitch --watermark ./logo.png --wm-width 150
```

### Available Flags
| **Flag** | **Short** | **Description** |
|---|---|---|
| --input | -i | Folder containing .mp4 files (defaults to current dir). |
| --output | -o | Target folder for processed files. |
| --lut | -l | Path to a .cube file for color grading. |
| --grain | -gr | Adds a high-quality film grain noise filter. |
| --glitch | -gl | Adds an anaglyphic RGB shift glitch effect. |
| --watermark | -wm | Path to a PNG/JPG to overlay in the bottom-right. |
| --wm-width | -ww | Set watermark width in pixels (Default: 120). |
| --bitrate | -b | Video bitrate (Default: 15000k). |

# ⚙️ Features
**1** **Smart Upscaling**: Uses the **Lanczos** algorithm to scale sub-1080p footage up to 1920x1080.
**2** **Hardware Acceleration**: Uses hevc_videotoolbox to ensure the CPU isn't a bottleneck.
**3** **Filename Slugification**: Automatically converts messy filenames (e.g., Mixkit Video (HD).mp4) into clean, URL-friendly slugs (e.g., mixkit-video-hd-1080.mp4).
**4** **Auto-Naming**: Appends metadata to the filename (like -1080, -grain, -glitch) so you know exactly what filters were applied without opening the file.
**5** **Denoising & Sharpening**: Applies hqdn3d and unsharp filters to clean up upscaled footage.

⠀📄 License
This project is open-source. See the individual script headers for specific logic details.

#WebDev