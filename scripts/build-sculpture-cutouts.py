#!/usr/bin/env python3
"""Offline photographic masking. No generated pixels, retouching or recolouring.

Dependencies: Pillow, NumPy, opencv-python-headless. Source photos stay outside
the repository. The checked-in masks make later builds independent of GrabCut.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "scripts/artwork/sculpture-cutouts.json"


def cutout(photo, spec, mask_path, refine):
    rgb = ImageOps.exif_transpose(photo).convert("RGB")
    if "source_crop" in spec:
        rgb = rgb.crop(spec["source_crop"])
    # Work at source resolution up to 1600px for stable, inexpensive edge search.
    rgb.thumbnail((1600, 1600), Image.Resampling.LANCZOS)
    if mask_path.exists() and not refine:
        mask = Image.open(mask_path).convert("L")
        assert mask.size == rgb.size
    else:
        import cv2
        import numpy as np
        w, h = rgb.size
        rw, rh = spec["reference_size"]
        polygon = [(round(x * w / rw), round(y * h / rh)) for x, y in spec["outline"]]
        rough = Image.new("L", rgb.size)
        ImageDraw.Draw(rough).polygon(polygon, fill=255)
        seed = np.array(rough)
        band = spec["edge_band"]
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (band * 2 + 1, band * 2 + 1))
        inner, outer = cv2.erode(seed, kernel), cv2.dilate(seed, kernel)
        labels = np.full((h, w), cv2.GC_BGD, dtype=np.uint8)
        labels[outer > 0] = cv2.GC_PR_BGD
        labels[seed > 0] = cv2.GC_PR_FGD
        labels[inner > 0] = cv2.GC_FGD
        cv2.setRNGSeed(0)
        cv2.setNumThreads(1)
        cv2.grabCut(np.array(rgb), labels, None, np.zeros((1, 65)), np.zeros((1, 65)), 5, cv2.GC_INIT_WITH_MASK)
        alpha = np.where((labels == cv2.GC_FGD) | (labels == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
        # Reject disconnected background scraps; never alter the photograph.
        count, components, stats, _ = cv2.connectedComponentsWithStats(alpha)
        if count > 1:
            keep = 1 + stats[1:, cv2.CC_STAT_AREA].argmax()
            alpha[components != keep] = 0
        mask = Image.fromarray(alpha)
        ew, eh = spec.get("exclude_reference_size", spec["reference_size"])
        for region in spec.get("exclude", []):
            ImageDraw.Draw(mask).polygon([(round(x*w/ew), round(y*h/eh)) for x, y in region], fill=0)
        mask = mask.filter(ImageFilter.GaussianBlur(.45))
        mask_path.parent.mkdir(parents=True, exist_ok=True)
        mask.save(mask_path)
    rgba = rgb.convert("RGBA")
    rgba.putalpha(mask)
    bounds = mask.point(lambda v: 255 if v >= 24 else 0).getbbox()
    assert bounds
    width, height = spec.get("canvas_size", (1024, 1536))
    fit_width, fit_height = width - 96, height - 128
    crop = rgba.crop(bounds)
    crop.thumbnail((fit_width, fit_height), Image.Resampling.LANCZOS)
    # Upscale only by proportional interpolation, never generative superresolution.
    ratio = min(fit_width / crop.width, fit_height / crop.height)
    if ratio > 1:
        crop = crop.resize((round(crop.width * ratio), round(crop.height * ratio)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (width, height))
    canvas.paste(crop, ((width - crop.width) // 2, height - 48 - crop.height))
    return canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--spec", type=Path, default=SPEC)
    parser.add_argument("--refine", action="store_true", help="Regenerate reviewed masks from outlines")
    parser.add_argument("--only")
    parser.add_argument("--previews", action="store_true")
    args = parser.parse_args()
    config = json.loads(args.spec.read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    for spec in config["assets"]:
        if args.only and args.only not in spec["file"]:
            continue
        source = args.sources / spec["source_file"]
        mask = ROOT / "scripts/artwork/sculpture-masks" / spec["file"]
        with Image.open(source) as photo:
            result = cutout(photo, spec, mask, args.refine)
        target = args.output / spec["file"]
        result.save(target, optimize=True)
        if args.previews:
            with Image.open(source) as original:
                grid = ImageOps.exif_transpose(original).convert("RGB")
                if "source_crop" in spec:
                    grid = grid.crop(spec["source_crop"])
                grid.thumbnail((900, 1200))
            draw = ImageDraw.Draw(grid)
            for x in range(0, grid.width, 50):
                draw.line((x, 0, x, grid.height), fill="#ee6677", width=1)
                draw.text((x+2, 2), str(x), fill="#ff0000", stroke_width=1, stroke_fill="white")
            for y in range(50, grid.height, 50):
                draw.line((0, y, grid.width, y), fill="#ee6677", width=1)
                draw.text((2, y+2), str(y), fill="#ff0000", stroke_width=1, stroke_fill="white")
            grid.save(args.output / (spec["file"] + ".grid.jpg"))
            preview = Image.new("RGB", (800, 600), "#eee9de")
            ImageDraw.Draw(preview).rectangle((400, 0, 800, 600), fill="#252620")
            small = result.copy()
            small.thumbnail((400, 600), Image.Resampling.LANCZOS)
            preview.paste(small, ((400-small.width)//2, 600-small.height), small)
            preview.paste(small, (400+(400-small.width)//2, 600-small.height), small)
            preview.save(args.output / (spec["file"] + ".preview.jpg"))
        bbox = result.getchannel("A").point(lambda v: 255 if v >= 24 else 0).getbbox()
        record = {k: v for k, v in spec.items() if k not in ("reference_size", "edge_band", "outline", "exclude_reference_size", "exclude", "display_scale", "canvas_size")}
        scale = spec.get("display_scale", 1.0)
        record.update(kind="Masked original photograph", method=config["method"],
                      sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                      source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                      mask_sha256=hashlib.sha256(mask.read_bytes()).hexdigest(),
                      width=result.width, height=result.height, alpha_bbox_at_24=list(bbox),
                      placement={"scale": scale, "anchor": "bottom", "lift": round(-.8 * scale * (1-bbox[3]/result.height)+.002, 4)})
        record["info"] += "\nOrbitUI: bakgrunden bortmaskad och bilden proportionellt skalad. Inga genererade skulpturdetaljer eller färgändringar."
        records.append(record)
        print(spec["file"], bbox, record["sha256"])
    suffix = "-" + args.only if args.only else ""
    (args.output / ("provenance" + suffix + ".json")).write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
