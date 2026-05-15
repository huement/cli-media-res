from moviepy import ImageClip
import moviepy.video.fx as vfx

clip = ImageClip(color=(0,0,0), size=(100,100), duration=1)
print(f"Attributes of ImageClip: {[attr for attr in dir(clip) if 'fade' in attr]}")
print(f"Attributes of vfx: {[attr for attr in dir(vfx) if 'fade' in attr]}")