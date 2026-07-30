import os
import re
import argparse
from pathlib import Path
from moviepy import VideoFileClip
from moviepy.video.fx.Resize import Resize
from rich.console import Console
from rich.progress import (
    Progress,
    SpinnerColumn,
    TextColumn,
    BarColumn,
    TimeElapsedColumn,
)

console = Console()


def slugify(text):
    name_only = Path(text).stem
    slug = re.sub(r"[^a-z0-9]+", "-", name_only.lower())
    return slug.strip("-")


def convert_vid_to_gif(input_path, width=800, fps=15):
    input_path = Path(input_path).resolve()
    output_path = input_path.parent / f"{slugify(input_path.name)}.gif"

    if not input_path.exists():
        console.print(f"[bold red]Error:[/bold red] File not found at {input_path}")
        return

    try:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TimeElapsedColumn(),
            console=console,
        ) as progress:
            task = progress.add_task(
                description=f"Converting {input_path.name} (Max Width: {width}px, {fps} FPS)...",
                total=None,
            )

            # Load the video
            clip = VideoFileClip(str(input_path))

            # Resize while maintaining aspect ratio
            if clip.w > width:
                clip = clip.with_effects([Resize(width=width)])

            # Write the GIF with v2.x optimizations
            clip.write_gif(str(output_path), fps=fps, logger=None)

            progress.update(
                task,
                completed=True,
                description=f"[bold green]Done:[/bold green] {output_path.name}",
            )

    except Exception as e:
        console.print(f"[bold red]Error processing {input_path.name}:[/bold red] {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert video files into optimized, lighter animated GIFs."
    )

    # ADDED DASHES HERE: Now matches the flag sent by your TUI orchestrator
    parser.add_argument(
        "--inputs", required=True, help="One or more input video file paths"
    )

    # Optional performance levers
    parser.add_argument(
        "--width",
        type=int,
        default=600,
        help="Target max width for the output GIF (default: 600)",
    )
    parser.add_argument(
        "--fps",
        type=int,
        default=12,
        help="Frames per second for output GIF (default: 12)",
    )

    args = parser.parse_args()

    # Cleanly split space-separated paths out of the TUI input box string
    target_files = args.inputs.split()

    for file_arg in target_files:
        convert_vid_to_gif(input_path=file_arg, width=args.width, fps=args.fps)
