
# 🎛️ CLI Media Resource Suite & TUI Orchestrator

[![Python Version](https://img.shields.io/badge/python-3.12%20%7C%203.14-blue.svg)](https://www.python.org/downloads/)
[![TUI Framework](https://img.shields.io/badge/TUI_Framework-Textual-ff5f87.svg?logo=python&logoColor=white)](https://github.com/Textualize/textual)
[![Platform Support](https://img.shields.io/badge/Platform-macOS_Apple_Silicon_%7C_AMD-black.svg?logo=apple&logoColor=white)](https://www.apple.com/)
[![Acceleration Engine](https://img.shields.io/badge/Hardware_Accel-VideoToolbox-success.svg?logo=ffmpeg&logoColor=white)](https://ffmpeg.org/)
[![Video Core](https://img.shields.io/badge/Video_Engine-MoviePy_v2.x-brightgreen.svg)](https://zulko.github.io/moviepy/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A unified, interactive terminal ecosystem for automating high-performance video optimization, folder-based smart GIF generation, and advanced media processing on macOS.
This repository features a centralized **Textual TUI Orchestrator Engine** that dynamically compiles user interfaces from simple YAML definitions, routing distinct computational modules through isolated, version-optimized virtual environments.

## ✨ Features

* **Dynamic TUI Blueprint Framework (app.py)**: An interactive dashboard powered by Textual. Add a new script, drop a simple YAML configuration into /tools, and the TUI will instantly auto-generate inputs, selects, and execution blocks.
* **Isolated Multi-Venv Routing Engine**: Built-in environment mapping allows your primary TUI to run on cutting-edge runtimes (e.g., Python 3.14) while seamlessly delegating complex modules (like legacy TensorFlow blocks) to completely separate, isolated virtual environments (e.g., Python 3.12).
* **Smart-Crop Bounding Box Engine (pyGifr.py)**: Scans directories of images, automatically detects the absolute smallest bounding target resolution, and compiles them into beautifully centered, aspect-filled, fading animated GIFs and MP4s.
* **Optimized Video-to-GIF Suite (vid2gif.py)**: A modern rendering layer utilizing MoviePy 2.x with explicit control scales for dimensions and frame rates to prevent file-size bloating.
* **Hardware Accelerated Shell Hooks (vidpro.sh)**: Direct integration with Apple VideoToolbox for blazing-fast HEVC/H.265 video upscaling, sharpening, and color grading utilizing macOS GPU architectures.

### 📁 Repository Architecture

```plaintext
cli-media-res/
│
├── TUI/                          # Main TUI Orchestrator Space
│   ├── app.py                    # Core Textual Dashboard App
│   ├── venv/                     # Primary TUI Venv (Python 3.14+)
│   └── tools/                    # Dynamic UI Manifest YAMLs
│       ├── pyGifr.yaml
│       ├── video_to_gif.yaml
│       └── cartoonize.yaml
│
├── gifs/                         # Shared Suite for Media Transcoding
│   ├── .venv/                    # Secondary Venv for MoviePy / Pillow (Python 3.14)
│   ├── pyGifr.py                 # Folder Bounding-Box Creator
│   └── vid2gif.py                # High-Compression Video-to-GIF Converter
│
├── ai_tools/                     # Specialized Machine Learning Space
│   ├── venv_312/                 # Deep Learning Isolated Venv (Python 3.12)
│   └── cartoonize.py             # Neural Net Multi-Engine Stylizer
│
└── legacy_bash/                  # Bare-Metal Hardware Accelerated Scripts
    ├── vidpro.sh                 # All-in-one Lanczos Upscaler & Filter Script
    └── bash-args.sh              # Custom CLI Associative Array Parsing Library
```

## 🛠️ System Pre-requisites

This suite leverages low-level system binaries for hardware acceleration. Before initializing the Python layer, set up your core macOS utilities via Homebrew:


```bash
# Update local Bash (macOS defaults to v3.2; Scripts require v4.0+ for associative arrays)
brew install bash

# Install system FFmpeg with active Apple VideoToolbox codecs
brew install ffmpeg ffprobe
```

## 🚀 Environment Setup & Installation

To run the full decoupled environment suite securely without crashing dependency paths, initialize your virtual sandboxes independently:

### 1. Initialize the Core TUI Application

```bash
cd TUI
python3 -m venv venv
source venv/bin/activate
pip install textual rich pyyaml
deactivate
```

### 2. Initialize the GIF Production Engine

```bash
cd ../gifs
python3 -m venv .venv
source .venv/bin/activate
pip install moviepy pillow rich
deactivate
```

### 3. Initialize the Machine Learning Studio(Optional)

```bash
cd ../ai_tools
python3.12 -m venv venv_312
source venv_312/bin/activate
pip install tensorflow==2.15.0 opencv-python numpy==1.25.2 sk-video
deactivate
```

## 🎛️ How the Dynamic Forms Work

Adding a new tool to your terminal dashboard requires zero interface programming. You simply map its command structure into a YAML format inside TUI/tools/:

```yaml
id: "video_to_gif"
name: "Video to Optimized GIF"
script_path: "./gifs/vid2gif.py"
description: "Compress and convert video files into highly optimized animated GIFs."

arguments:
  - flag: "--inputs"
    name: "Input Video Path(s)"
    type: "text"
    placeholder: "/path/to/video.mp4"
    required: true

  - flag: "--width"
    name: "Max Width (Pixels)"
    type: "integer"
    default: "600"

  - flag: "--fps"
    name: "Frame Rate (FPS)"
    type: "integer"
    default: "12"
```


The orchestrator instantly interprets this layout, constructs appropriate terminal widgets, performs text validations, and hooks the runtime parameters into safe, shell-escaped `subprocess.Popen` execution threads.

## 💻 Manual Terminal Execution

All tools can be run independently from the terminal outside of the UI orchestrator using their explicit native virtual environment bins:

**Convert a Heavy MP4 into a Compressed 12 FPS Web-Ready GIF:**

```bash
./gifs/.venv/bin/python ./gifs/vid2gif.py --inputs ./inputs/sample.mp4 --width 600 --fps 12
```

**Batch Compile a Folder of High-Resolution Frames using Automated Crop-Matching:**

```bash
./gifs/.venv/bin/python ./gifs/pyGifr.py --dirs ./inputs/rendering_frames --fps 15
```

**Run Hardware Accelerated H.265 GPU Upscaling (Bare-Metal Shell):**

```bash
./legacy_bash/vidpro.sh --input ~/Movies/Source --output ~/Movies/Optimized --lut ./CineGrade.cube --grain
```

## License & Sponsorship

Distributed freely under the open-source **MIT License**. Maintained, optimized, and engineered / sponsored by **[HUEMENT](https://huement.com/)**.
This ecosystem is open-source. Review individual module code structures and engine script headers for specialized processing details.

<p align="center">
  <strong>If this software saved you time or a headache, consider keeping the engine running!</strong><br><br>
  <a href='https://ko-fi.com/U1A7222617' target='_blank'>
    <img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' />
  </a>
</p>

**NOTE** If you want a specific feature added, I do freelance work and would be more than happy to work something out. [Contact Me Here](https://huement.com/contact)
