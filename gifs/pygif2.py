import os
import sys
from pathlib import Path

# NEW: Version 2.0+ imports
from moviepy import ImageClip, concatenate_videoclips, vfx

def make_cyberpunk_movie_gif(input_folder, output_name="cyber_movie.gif"):
    # --- Configuration ---
    target_width = 1200
    img_duration = 3.0   # Total time each image is "active"
    fade_duration = 0.5  # Duration of the fade in/out
    fps = 12             # GIF frame rate
    # ---------------------

    input_path = Path(input_folder).resolve()
    files = sorted([f for f in input_path.glob("*.png") if not f.name.startswith('.')])
    
    if not files:
        print("❌ No PNG files found.")
        return

    print(f"🎬 Creating cinematic sequence for {len(files)} images...")

    clips = []
    for img_file in files:
        # 1. Create a clip from the image
        clip = ImageClip(str(img_file))
        
        # 2. Resize (using the new .resized method)
        clip = clip.resized(width=target_width)
        
        # 3. Apply Duration and Fades
        # In MoviePy 2.0, we use .with_duration and .with_effects
        clip = (clip
                .with_duration(img_duration)
                .with_effects([
                    vfx.FadeIn(fade_duration), 
                    vfx.FadeOut(fade_duration)
                ]))
        
        clips.append(clip)
        print(f"  [+] Added {img_file.name}")

    # 4. Concatenate all clips
    final_video = concatenate_videoclips(clips, method="compose")

    print("🎨 Rendering high-quality GIF (this may take a moment)...")
    
    # 5. Write the GIF
    final_video.write_gif(
        output_name, 
        fps=fps,
        loop=0
    )

    print(f"✨ Done! Created: {output_name}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 script.py /path/to/screenshots")
    else:
        make_cyberpunk_movie_gif(sys.argv[1])