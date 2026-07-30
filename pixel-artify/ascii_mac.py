import sys
from PIL import Image

ASCII_CHARS = ["@", "#", "S", "%", "?", "*", "+", ";", ":", ",", "."]

def image_to_ascii(image_path, width=80):
    try:
        img = Image.open(image_path).convert("L")
    except Exception as e:
        print(f"Error loading image: {e}")
        return

    # Adjust vertical scale for Mac Terminal font height
    w, h = img.size
    aspect = h / w
    height = int(width * aspect * 0.5)
    img = img.resize((width, height))

    pixels = img.getdata()
    ascii_str = "".join([ASCII_CHARS[p // 25] for p in pixels])

    # Print line by line
    for i in range(0, len(ascii_str), width):
        print(ascii_str[i:i + width])

if __name__ == "__main__":
    if len(sys.argv) > 1:
        image_to_ascii(sys.argv[1])
    else:
        print("Usage: python3 ascii_mac.py <path_to_image>")