#!/bin/bash

# Loop through all mp4 files in the current directory
for file in *.mp4; do
    # Check if file exists to avoid errors if folder is empty
    [ -e "$file" ] || continue

    echo "Processing: $file"

    # --------------------------
    # 1. PARSE THE FILENAME
    # --------------------------

    # Remove the prefix "mixkit-" (or everything up to the first dash)
    # ${file#*-} removes the shortest match of "*-" from the front
    temp_name="${file#*-}"

    # Remove suffix starting at the 3rd to last dash
    # Logic: Reverse string -> cut first 3 fields (which are the last 3 parts) -> Reverse back
    # Example: ...-nebulae-5399-hd-ready.mp4
    # Reversed: 4pm.ydaer-dh-9935-ealuben-...
    # Cut -f4-: Keeps "ealuben-..." (drops 4pm.ydaer, dh, 9935)
    clean_name=$(echo "$temp_name" | rev | cut -d- -f4- | rev)

    # Construct the final output name
    output_name="${clean_name}-1080.mp4"

    # --------------------------
    # 2. RUN FFMPEG UPSCALING
    # --------------------------
    
    # -vf "scale=1920:1080:flags=lanczos": Upscale using high-quality Lanczos algorithm
    # -c:v hevc_videotoolbox: Use macOS Hardware Acceleration (works with AMD)
    # -b:v 12000k: Set high bitrate (12Mbps) for pristine quality
    # -c:a copy: Copy audio stream without re-encoding (preserves original quality)
    
    ffmpeg -i "$file" \
        -vf "scale=1920:1080:flags=lanczos" \
        -c:v hevc_videotoolbox \
        -b:v 12000k \
        -c:a copy \
        -n \
        "$output_name"

    echo "Finished: $output_name"
    echo "-----------------------------------"
done
