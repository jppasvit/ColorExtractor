# scripts/extract_colors.py
import sys
import json
from colorthief import ColorThief

path = sys.argv[1]
ct = ColorThief(path)

palette = ct.get_palette(color_count=5)
# Convert RGB tuples to hex
colors = ['#%02x%02x%02x' % color for color in palette]

print(json.dumps(colors))
