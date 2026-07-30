#!/usr/bin/env python3
import argparse
from pathlib import Path

def clean_filenames(string_to_remove: str, target_dir: str = "."):
    folder = Path(target_dir)
    if not folder.is_dir():
        print(f"Error: Directory not found: {target_dir}")
        return

    renamed_count = 0
    for item in folder.iterdir():
        if item.is_file() and string_to_remove in item.name:
            new_name = item.name.replace(string_to_remove, "")
            new_path = item.parent / new_name
            item.rename(new_path)
            print(f"Renamed: {item.name} → {new_name}")
            renamed_count += 1

    print("-----------------------------------")
    print(f"Done cleaning filenames! Renamed {renamed_count} file(s).")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Remove a specific substring from filenames in a folder")
    parser.add_argument("substring", help="Substring to remove")
    parser.add_argument("--directory", default=".", help="Target directory")
    args = parser.parse_args()
    
    clean_filenames(args.substring, args.directory)