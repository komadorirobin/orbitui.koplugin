#!/usr/bin/env python3
"""Optional visual QA contact sheet. Requires cairosvg and Pillow, not used at runtime."""
import argparse
from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/vector-icons"


def preview(output):
    canvas = Image.new("RGB", (880, 440), "#f5f4f0")
    draw = ImageDraw.Draw(canvas)
    title = ImageFont.load_default(size=22)
    label = ImageFont.load_default(size=16)

    def icon(pack, name, x, y, size):
        data = cairosvg.svg2png(url=str(BASE / pack / (name + ".svg")),
                              output_width=size, output_height=size)
        rendered = Image.open(BytesIO(data)).convert("RGBA")
        canvas.paste(rendered, (x, y), rendered)

    for column, (pack, text) in enumerate((("solar-outline", "Solar Outline"),
                                          ("solar-duotone", "Solar Line Duotone"))):
        left = column * 440
        draw.text((left + 220, 30), text, fill="#222222", font=title, anchor="mm")
        icon(pack, "manga", left + 140, 65, 160)
        draw.text((left + 220, 246), "Manga (OrbitUI)", fill="#444444", font=label, anchor="mm")
        for i, name in enumerate(("home", "book", "manga", "power")):
            icon(pack, name, left + 78 + i * 80, 296, 48)
        draw.text((left + 220, 387), "48 px navigation preview", fill="#666666", font=label, anchor="mm")
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    preview(parser.parse_args().output)
