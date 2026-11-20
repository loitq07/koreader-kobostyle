import re
import os
import shutil
import json

base_dir = r"D:\Projects\koreader-kobostyle\kobo-dashboard\fonts"
src_css = os.path.join(base_dir, "raw", "package", "src", "regular", "style.css")
src_ttf = os.path.join(base_dir, "raw", "package", "src", "bold", "Phosphor-Bold.ttf")
dest_ttf = os.path.join(base_dir, "Phosphor-Bold.ttf")

shutil.copy2(src_ttf, dest_ttf)

with open(src_css, "r", encoding="utf-8") as f:
    css = f.read()

# Pattern: .ph-sun:before { content: "\e45c"; }
icons = {}
for m in re.finditer(r'\.ph-([a-z0-9-]+):before\s*\{\s*content:\s*"\\([0-9a-fA-F]+)"', css):
    name = m.group(1)
    code = chr(int(m.group(2), 16))
    icons[name] = code

out_json = os.path.join(base_dir, "phosphor_icons.json")
with open(out_json, "w", encoding="utf-8") as f:
    json.dump({k: ord(v) for k, v in icons.items()}, f, indent=2)

print(f"Total Phosphor icons mapped: {len(icons)}")
for test in ["sun", "cloud", "drop", "wind", "robot", "clock", "check-square", "cpu", "sparkle", "battery-high", "calendar", "chart-bar", "thermometer"]:
    ch = icons.get(test)
    if ch:
        print(f"Icon {test}: {hex(ord(ch))}")
    else:
        print(f"Icon {test}: NOT FOUND")
