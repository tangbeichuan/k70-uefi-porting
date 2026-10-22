from PIL import Image, ImageDraw, ImageFont
import pathlib, glob
cands = ["C:/Windows/Fonts/consola.ttf","C:/Windows/Fonts/cour.ttf","C:/Windows/Fonts/lucon.ttf"]
font_path = next((c for c in cands if pathlib.Path(c).exists()), None)
print("font:", font_path)
f = ImageFont.truetype(font_path, 14)
rows, cols = 16, 8
lines = []
for code in range(32, 127):
    ch = chr(code)
    img = Image.new('1', (cols, rows), 0)
    d = ImageDraw.Draw(img)
    d.text((0, 0), ch, font=f, fill=1)
    data = []
    for y in range(rows):
        b = 0
        for x in range(cols):
            if img.getpixel((x, y)):
                b |= (1 << (7 - x))
        data.append(b)
    lines.append((code, data))
out = []
out.append("// auto-generated 8x16 ASCII font (32..126), rows top->bottom, MSB = leftmost pixel")
out.append("#pragma once")
out.append("#include <Uefi.h>")
out.append("STATIC CONST UINT8 mFont8x16[95][16] = {")
for code, data in lines:
    hexs = ", ".join("0x%02X" % b for b in data)
    out.append("  { %s },  // %d" % (hexs, code))
out.append("};")
pathlib.Path(r"D:\本地项目-01\_tools\font8x16.h").write_text("\n".join(out), encoding="utf-8")
print("written, glyph count:", len(lines))