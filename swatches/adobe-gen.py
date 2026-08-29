import struct

def encode_ase_string(text):
    """Encode string as UTF-16BE with a null-terminator."""
    encoded = text.encode('utf-16be') + b'\x00\x00'
    length = len(text) + 1  # Character count including null terminator
    return struct.pack('>H', length) + encoded

def build_color_block(name, r, g, b):
    """Build binary block for a single RGB color entry."""
    name_bytes = encode_ase_string(name)
    color_data = name_bytes + b'RGB ' + struct.pack('>fff', r / 255.0, g / 255.0, b / 255.0) + struct.pack('>H', 0)
    block_len = len(color_data)
    return struct.pack('>HI', 0x0001, block_len) + color_data

def build_group_blocks(group_name, colors):
    """Build blocks for group start, color entries, and group end."""
    group_name_bytes = encode_ase_string(group_name)
    group_start_len = len(group_name_bytes)
    group_start = struct.pack('>HI', 0xC001, group_start_len) + group_name_bytes
    
    color_blocks = [build_color_block(name, r, g, b) for name, (r, g, b) in colors.items()]
    group_end = struct.pack('>HI', 0xC002, 0)
    
    return [group_start] + color_blocks + [group_end]

# Tokyo Night Colors (Dark & Light)
tokyo_night_dark = {
    "TN Dark / BG Primary": (26, 27, 38),
    "TN Dark / BG Dark": (22, 22, 30),
    "TN Dark / BG Dark 2": (18, 18, 24),
    "TN Dark / BG Highlight": (41, 46, 66),
    "TN Dark / BG Highlight Dark": (36, 40, 59),
    "TN Dark / Terminal Black": (65, 72, 104),
    "TN Dark / Foreground": (192, 202, 245),
    "TN Dark / Foreground Dark": (169, 177, 214),
    "TN Dark / Comment": (86, 95, 137),
    "TN Dark / Blue 0": (61, 89, 161),
    "TN Dark / Blue": (122, 162, 247),
    "TN Dark / Cyan": (125, 207, 255),
    "TN Dark / Magenta": (187, 154, 247),
    "TN Dark / Pink": (217, 0, 105),
    "TN Dark / Orange": (255, 158, 100),
    "TN Dark / Yellow": (224, 175, 104),
    "TN Dark / Green": (158, 206, 106),
    "TN Dark / Teal": (26, 188, 156),
    "TN Dark / Red": (255, 117, 127),
    "TN Dark / Red 1": (219, 75, 75)
}

tokyo_night_light = {
    "TN Light / BG Primary": (213, 214, 219),
    "TN Light / BG Dark": (203, 204, 209),
    "TN Light / BG Dark 2": (188, 189, 194),
    "TN Light / BG Highlight": (220, 222, 226),
    "TN Light / BG Highlight Dark": (195, 197, 201),
    "TN Light / Terminal Black": (15, 15, 20),
    "TN Light / Foreground": (52, 59, 88),
    "TN Light / Foreground Dark": (39, 46, 75),
    "TN Light / Comment": (150, 153, 163),
    "TN Light / Blue 0": (39, 71, 125),
    "TN Light / Blue": (52, 84, 138),
    "TN Light / Cyan": (15, 75, 110),
    "TN Light / Magenta": (90, 74, 120),
    "TN Light / Pink": (109, 74, 120),
    "TN Light / Orange": (150, 80, 39),
    "TN Light / Yellow": (143, 94, 21),
    "TN Light / Green": (51, 99, 92),
    "TN Light / Teal": (22, 103, 117),
    "TN Light / Red": (140, 67, 81),
    "TN Light / Red 1": (115, 42, 56)
}

# Collect all blocks
all_blocks = []
all_blocks.extend(build_group_blocks("Tokyo Night Dark", tokyo_night_dark))
all_blocks.extend(build_group_blocks("Tokyo Night Light", tokyo_night_light))

# Build header with the correct total block count
header = b'ASEF' + struct.pack('>HH', 1, 0) + struct.pack('>I', len(all_blocks))

# Write file
with open("tokyo_night.ase", "wb") as f:
    f.write(header + b''.join(all_blocks))

print(f"Successfully generated 'tokyo_night.ase' with {len(all_blocks)} total blocks!")
