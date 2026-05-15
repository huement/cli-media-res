import os
import re
from pathlib import Path
from moviepy import VideoFileClip
from moviepy.video.fx.Resize import Resize
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeElapsedColumn

console = Console()

def slugify(text):
    name_only = Path(text).stem
    slug = re.sub(r'[^a-z0-9]+', '-', name_only.lower())
    return slug.strip('-')

def convert_vid_to_gif(input_path, width=800, fps=15):
    input_path = Path(input_path).resolve()
    output_path = input_path.parent / f"{slugify(input_path.name)}.gif"

    try:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TimeElapsedColumn(),
            console=console
        ) as progress:
            
            task = progress.add_task(description=f"Converting {input_path.name}...", total=None)
            
            # Load the video
            clip = VideoFileClip(str(input_path))
            
            # Resize while maintaining aspect ratio
            if clip.w > width:
                clip = clip.with_effects([Resize(width=width)])
            
            # Write the GIF
            # MoviePy uses imageio/ffmpeg under the hood
            clip.write_gif(str(output_path), fps=fps, logger=None)
            
            progress.update(task, completed=True, description=f"[bold green]Done:[/bold green] {output_path.name}")
            
    except Exception as e:
        console.print(f"[bold red]Error processing {input_path.name}:[/bold red] {e}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        console.print("[yellow]Usage:[/yellow] python app.py video1.mp4 video2.mp4")
    else:
        for file_arg in sys.argv[1:]:
            convert_vid_to_gif(file_arg)