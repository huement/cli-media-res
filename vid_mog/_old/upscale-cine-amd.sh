#!/bin/bash

# --------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------
# 1. Name of your LUT file. 
# If it's in a different folder, put the full path here (e.g., "/Users/name/Desktop/FGCineDrama.cube")
LUT_PATH="/Users/eris/Movies/FGCineTealOrange2.cube"

# Check if LUT exists before starting
if [ ! -f "$LUT_PATH" ]; then
    echo "❌ Error: Could not find LUT file: $LUT_PATH"
    echo "Please make sure the .cube file is in this folder."
    exit 1
fi

# If a folder was passed, use it; otherwise use current directory
INPUT_DIR="${1:-.}"

# Move into that directory
cd "$INPUT_DIR" || { echo "Folder not found: $INPUT_DIR"; exit 1; }

# --------------------------------------------------------
# PROCESSING LOOP
# --------------------------------------------------------
for file in *.mp4; do
    # Check if file exists
    [ -e "$file" ] || continue

    echo "Processing: $file"

    # --- 1. PARSE FILENAME ---
    temp_name="${file#*-}"
    clean_name=$(echo "$temp_name" | rev | cut -d- -f4- | rev)
    output_name="${clean_name}-1080-graded-teal.mp4"

    # --- 2. RUN FFMPEG (Upscale + LUT + Encode) ---
    
    # EXPLANATION OF THE FILTER CHAIN (-vf):
    # 1. scale=1920:1080:flags=lanczos  -> Upscale to 1080p using high-quality Lanczos
    # 2. lut3d=file='...'               -> Apply the color grade
    # 3. format=yuv420p                 -> Convert colors back to video standard (Crucial for hardware encoding)

	# ffmpeg -i "$file" \
# 	        -vf "scale=1920:1080:flags=lanczos,lut3d=file='$LUT_PATH',format=yuv420p" \
# 	        -c:v hevc_videotoolbox \
# 	        -b:v 12000k \
# 	        -c:a copy \
# 	        -n \
# 	        "$output_name"

	# ffmpeg -i "$file" \
	#         -vf "scale=1920:1080:flags=lanczos,unsharp=3:3:0.5:3:3:0.5,lut3d=file='$LUT_PATH',noise=alls=2:allf=t,format=yuv420p" \
	#         -c:v hevc_videotoolbox \
	#         -b:v 15000k \
	#         -c:a copy \
	#         -n \
	#         "$output_name"

	# ffmpeg -i "$file" \
	#     -vf "hqdn3d=0.5:0.5:3:3,\
	# scale=1920:1080:flags=lanczos,\
	# unsharp=2:2:0.4:2:2:0.4,\
	# lut3d=file='$LUT_PATH',\
	# noise=alls=2:allf=t,\
	# format=yuv420p:dither=bayer" \
	#     -c:v hevc_videotoolbox \
	#     -b:v 20000k \
	#     -c:a copy \
	#     -n \
	#     "$output_name"
	
	ffmpeg -i "$file" \
	        -vf "hqdn3d=0.5:0.5:3:3,scale=1920:1080:flags=lanczos,unsharp=3:3:0.5:3:3:0.5,lut3d=file='$LUT_PATH',noise=alls=2:allf=t,format=yuv420p" \
	        -c:v hevc_videotoolbox \
	        -b:v 15000k \
	        -tag:v hvc1 \
	        -c:a copy \
	        -n \
	        "$output_name"
	
	
    echo "✅ Finished: $output_name"
    echo "-----------------------------------"
done