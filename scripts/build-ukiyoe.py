#!/usr/bin/env python3
"""Maintainer-only builder: unchanged museum art, deterministic frames and theme.

Requires Pillow. Never runs on KOReader. Network is explicit (--fetch); cached
original bytes and the bundled provenance hashes make a rebuild auditable.
"""
import argparse
import hashlib
import html
import json
from pathlib import Path
import subprocess
from urllib.parse import urlparse

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, PngImagePlugin

ROOT = Path(__file__).resolve().parents[1]
PACK_NAME = "Ukiyo-e Gallery"
PACK = ROOT / "assets/ornaments" / PACK_NAME
CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"
ART_EDGE = 768
FRAME = 14
MAT = 16
PAD = 4
# Clear the plank's receding top surface as well as the books' foot line.
WALL_LIFT = .20
BASELINE_COMMIT = "17b3970c70985c3777d8552ac89b28a48d7129a9"
BASELINE = ROOT / "assets/ornament-updates/ukiyoe-gallery-v1.json"
V2_COMMIT = "d224901dcddbcc0d457a801058437cd20d2c0217"
V2_BASELINE = ROOT / "assets/ornament-updates/ukiyoe-gallery-v2.json"
MUSEUMS = {
    "cma": ("The Cleveland Museum of Art", "https://www.clevelandart.org/open-access"),
    "met": ("The Metropolitan Museum of Art", "https://www.metmuseum.org/hubs/open-access"),
}
HOSTS = {"openaccess-api.clevelandart.org", "openaccess-cdn.clevelandart.org",
         "collectionapi.metmuseum.org", "images.metmuseum.org"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def fetch(url, path, enabled):
    assert urlparse(url).scheme == "https" and urlparse(url).hostname in HOSTS
    if path.exists():
        return
    if not enabled:
        raise ValueError(f"Missing cached source {path}; use --fetch explicitly")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".part")
    subprocess.run(["curl", "-q", "--fail", "--silent", "--show-error", "--location",
                    "--proto", "=https", "--proto-redir", "=https", "--retry", "3",
                    "--max-time", "90", url, "--output", str(temporary)], check=True)
    temporary.replace(path)


def museum_record(selection, cache, online):
    museum, oid = selection["museum"], selection["id"]
    api = (f"https://openaccess-api.clevelandart.org/api/artworks/{oid}"
           if museum == "cma" else
           f"https://collectionapi.metmuseum.org/public/collection/v1/objects/{oid}")
    record = cache / f"{museum}-{oid}.json"
    fetch(api, record, online)
    doc = json.loads(record.read_text())
    if museum == "cma":
        item = doc["data"]
        assert item["id"] == oid and item["share_license_status"] == "CC0"
        assert "woodblock" in item["technique"].lower(), item["technique"]
        data = dict(title=item["title"], artist="; ".join(
            c["description"] for c in item["creators"] if c["role"] == "artist"),
            date=item["creation_date"], medium=item["technique"], measurements=item["measurements"],
            accession=item["accession_number"], credit=item["creditline"],
            object_url=item["url"], image_url=item["images"]["web"]["url"],
            rights_evidence={"share_license_status": "CC0"})
    else:
        assert doc["objectID"] == oid and doc["isPublicDomain"] is True
        assert "woodblock" in doc["medium"].lower(), doc["medium"]
        data = dict(title=doc["title"], artist=doc["artistDisplayName"],
            date=doc["objectDate"], medium=doc["medium"], measurements=doc["dimensions"], accession=doc["accessionNumber"],
            credit=doc["creditLine"], object_url=doc["objectURL"],
            image_url=doc["primaryImage"], rights_evidence={"isPublicDomain": True})
    original = cache / f"{museum}-{oid}.jpg"
    fetch(data["image_url"], original, online)
    data.update(selection, museum_name=MUSEUMS[museum][0],
                policy_url=MUSEUMS[museum][1], license="CC0 1.0", license_url=CC0,
                api_url=api, source_sha256=digest(original), record_sha256=digest(record))
    return data, original


def framed(original):
    # Never crop, recolour, quantize, sharpen, or generatively edit a museum work.
    art = original.convert("RGB")
    art.thumbnail((ART_EDGE, ART_EDGE), Image.Resampling.LANCZOS)
    margin = FRAME + MAT
    w, h = art.width + 2 * margin, art.height + 2 * margin
    out = Image.new("RGBA", (w + PAD * 2, h + PAD), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    # Keep the PNG flush at the bottom; native lift supplies the wall clearance.
    draw.rectangle((PAD + 2, PAD + 2, w + PAD + 2, h + PAD - 1), fill=(30, 25, 20, 40))
    x, y = PAD, PAD
    draw.rectangle((x, y, x + w - 1, y + h - 1), fill="#292820")
    draw.polygon([(x+1,y+1),(x+w-2,y+1),(x+w-FRAME,y+FRAME),
                  (x+FRAME,y+FRAME),(x+FRAME,y+h-FRAME),(x+1,y+h-2)], fill="#645747")
    draw.polygon([(x+w-2,y+1),(x+w-2,y+h-2),(x+1,y+h-2),
                  (x+FRAME,y+h-FRAME),(x+w-FRAME,y+h-FRAME),
                  (x+w-FRAME,y+FRAME)], fill="#3b332b")
    draw.rectangle((x+FRAME-2,y+FRAME-2,x+w-FRAME+1,y+h-FRAME+1), fill="#94836b")
    draw.rectangle((x+FRAME,y+FRAME,x+w-FRAME-1,y+h-FRAME-1), fill="#f1eadc")
    ax, ay = x + margin, y + margin
    draw.rectangle((ax-1,ay-1,ax+art.width,ay+art.height), fill="#b3a692")
    out.paste(art, (ax, ay))
    return out, (ax, ay, art.width, art.height)


def theme(washi, hinoki):
    target = PACK / "theme"
    target.mkdir(parents=True, exist_ok=True)
    with Image.open(washi) as source:
        wall = source.convert("RGB")
        wall.thumbnail((1264, 1680), Image.Resampling.LANCZOS)
        wall.save(target / "wallpaper.jpg", quality=90, subsampling=0, optimize=True)
    # Native three-band template: empty / wood / empty, middle band 80/20
    # surface/face. No end caps needed: Bookshelf clips its own corner bevels.
    width, band = 768, 120
    with Image.open(hinoki) as source:
        wood = source.convert("RGB").resize((width, band), Image.Resampling.LANCZOS)
    # Mirror a half tile to make the repeated grain's left/right pixels agree.
    left = wood.crop((0, 0, width // 2, band))
    wood.paste(left.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (width // 2, 0))
    plank = Image.new("RGBA", (width, band * 3), (0, 0, 0, 0))
    surface = round(band * .8)
    plank.paste(wood.crop((0, 0, width, surface)), (0, band))
    face = ImageEnhance.Brightness(wood.crop((0, surface, width, band))).enhance(.73)
    plank.paste(face, (0, band + surface))
    draw = ImageDraw.Draw(plank)
    draw.line((0, band + surface - 1, width - 1, band + surface - 1), fill="#f1dab1")
    draw.line((0, band * 2 - 1, width - 1, band * 2 - 1), fill="#887459")
    plank.save(target / "plank.Hinoki.middle.png", optimize=True)
    write_json(target / "theme.json", {
        "name": "Ukiyo-e Gallery", "shelf": "light", "plank": "Hinoki",
        "description": "27 public-domain Japanese woodblock prints with original OrbitUI frames, washi wallpaper and a hinoki-style plank.",
    })


def preview(assets):
    from urllib.parse import quote
    images = []
    for a in assets:
        src = "../assets/ornaments/" + quote(PACK_NAME + "/" + a["file"])
        images.append(f'<figure><div class="art"><img src="{src}" alt="{html.escape(a["title"], quote=True)}"></div>'
                      f'<figcaption>{html.escape(a["file"][:-4])}<small>{html.escape(a["date"])}</small></figcaption></figure>')
    text = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>OrbitUI | Ukiyo-e Gallery</title><style>
*{box-sizing:border-box}body{margin:0;background:#f4f0e6 url('../assets/ornaments/Ukiyo-e%20Gallery/theme/wallpaper.jpg');color:#262923;font:18px Georgia,serif;padding:40px}
header{max-width:880px;margin:0 auto 40px}h1{font-size:44px;font-weight:400;margin-bottom:12px}p{line-height:1.6}button{padding:12px 18px;border:1px solid #797365;background:#f4f0e6;font:inherit;cursor:pointer}
main{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:36px 24px;max-width:1400px;margin:auto}figure{margin:0;text-align:center;min-width:0}.art{--stand:218px;height:calc(var(--stand) + 12px);display:flex;align-items:end;justify-content:center;border-bottom:12px solid #cdb187;box-shadow:0 5px 5px #493d3322}
img{max-width:96%;max-height:calc(var(--stand) * .76);margin-bottom:calc(var(--stand) * WALL_LIFT);object-fit:contain}figcaption{font-size:15px;line-height:1.3;padding:12px 0}small{display:block;font-size:12px;margin-top:5px}body.bw main{filter:grayscale(1)}
@media(max-width:900px){main{grid-template-columns:repeat(3,minmax(0,1fr))}}@media(max-width:540px){body{padding:18px}main{grid-template-columns:repeat(2,minmax(0,1fr));gap:20px 12px}.art{--stand:178px}h1{font-size:32px}}
</style><header><h1>Ukiyo-e Gallery</h1><p>27 museum originals. Own frames, washi and hinoki-style shelf. This is an asset contact sheet, not a KOReader emulator. Click a print's museum link in provenance.json for the original.</p><button onclick="document.body.classList.toggle('bw')">Colour / grayscale preview</button></header><main>'''
    text = text.replace("WALL_LIFT", str(WALL_LIFT))
    (ROOT / "docs/ukiyoe-gallery-preview.html").write_text(text + "\n".join(images) + "</main></html>\n", encoding="utf-8")


def contact_sheet(assets):
    """Desktop visual QA only, deliberately excluded from the runtime ZIP."""
    sheet = Image.new("RGB", (1500, 1680), "#eee9dd")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, a in enumerate(assets):
        x, y = (index % 5) * 300, (index // 5) * 280
        with Image.open(PACK / a["file"]) as source:
            thumb = source.copy()
            thumb.thumbnail((260, round(240 * .76)), Image.Resampling.LANCZOS)
        bottom = y + 240 - round(240 * WALL_LIFT)
        sheet.paste(thumb, (x + (300-thumb.width)//2, bottom-thumb.height), thumb)
        draw.rectangle((x+10, y+240, x+290, y+250), fill="#c3a67b")
        draw.text((x+12, y+258), a["file"][:-4], fill="#202020", font=font)
    output = ROOT / "dist"
    output.mkdir(exist_ok=True)
    sheet.save(output / "ukiyoe-contact-sheet.jpg", quality=93)
    sheet.convert("L").save(output / "ukiyoe-grayscale-contact-sheet.jpg", quality=93)


def build(args):
    selection = json.loads((ROOT / "scripts/artwork/ukiyoe-selection.json").read_text())
    context = json.loads((ROOT / "scripts/artwork/ukiyoe-context.json").read_text())
    assert set(context) == {pick["file"] for pick in selection}
    # Frozen alpha.19 defaults for a field-wise, non-destructive reader upgrade.
    # Generated only once; ordinary rebuilds never require historical Git data.
    if not BASELINE.exists():
        old_files = {name: subprocess.check_output([
            "git", "show", f"{BASELINE_COMMIT}:assets/ornaments/{PACK_NAME}/{name}"
        ], cwd=ROOT).decode("utf-8") for name in
            ("ornaments.json", "provenance.json", "ATTRIBUTION.txt", "README.txt")}
        write_json(BASELINE, dict(source_commit=BASELINE_COMMIT, files=old_files))
    if not V2_BASELINE.exists():
        old_files = {name: subprocess.check_output([
            "git", "show", f"{V2_COMMIT}:assets/ornaments/{PACK_NAME}/{name}"
        ], cwd=ROOT).decode("utf-8") for name in ("ornaments.json", "README.txt")}
        # Only placement and the pack notice changed after alpha.20.
        placement = {name: {k: e[k] for k in ("lift", "scale", "anchor")}
                     for name, e in json.loads(old_files.pop("ornaments.json")).items()}
        write_json(V2_BASELINE, dict(source_commit=V2_COMMIT, placement=placement, files=old_files))
    PACK.mkdir(parents=True, exist_ok=True)
    previous = PACK / "provenance.json"
    locked = {a["file"]: a for a in json.loads(previous.read_text())["artworks"]} if previous.exists() else {}
    assets, settings = [], {}
    for pick in selection:
        data, original = museum_record(pick, args.cache, args.fetch)
        data["note"] = context[pick["file"]]["summary"]
        data["note_sources"] = list(dict.fromkeys([data["object_url"], *context[pick["file"]]["sources"]]))
        data["note_credit"] = "OrbitUI: AI-assisterad svensk sammanfattning av angivna museikällor, inte museets originaltext."
        if pick["file"] in locked:
            assert data["source_sha256"] == locked[pick["file"]]["source_sha256"], "Museum source changed; review before rebuilding"
            assert data["record_sha256"] == locked[pick["file"]]["record_sha256"], "Museum metadata changed; review before rebuilding"
        with Image.open(original) as source:
            image, box = framed(source)
            data["source_dimensions"] = list(source.size)
        pnginfo = PngImagePlugin.PngInfo()
        pnginfo.add_text("Source", data["object_url"])
        pnginfo.add_text("License", CC0)
        image.save(PACK / pick["file"], optimize=True, pnginfo=pnginfo)
        data.update(sha256=digest(PACK / pick["file"]), dimensions=list(image.size), art_box=list(box))
        assets.append(data)
        settings[pick["file"]] = dict(scale=.95, anchor="bottom", lift=WALL_LIFT, pad=.02,
            night="off", mirror="off", tap="zoom", info="\n\n".join([
                data["title"], data["artist"] + " | " + data["date"],
                data["medium"] + "\nMått (museets exemplar): " + data["measurements"],
                data["note"], data["note_credit"],
                data["museum_name"] + " | " + data["accession"], data["credit"],
                "Museibild: public domain / CC0 1.0. Originalet är proportionerligt förminskat, inte beskuret eller AI-bearbetat. Inramning: OrbitUI.",
                "Källor till kataloguppgifter och kommentar:\n" + "\n".join(data["note_sources"]), CC0]))
        assert len(settings[pick["file"]]["info"].encode("utf-8")) <= 4000, "Native info card byte limit exceeded"
        print(pick["file"], data["dimensions"], flush=True)
    write_json(PACK / "ornaments.json", settings)
    theme(args.washi, args.hinoki)
    generated = []
    for path in sorted((PACK / "theme").iterdir()):
        generated.append(dict(file=path.relative_to(PACK).as_posix(), sha256=digest(path)))
    write_json(PACK / "provenance.json", dict(schema=1, artworks=assets,
        processing="Proportional LANCZOS reduction only; RGB preserved, no crop, no AI edits of artworks. Original deterministic OrbitUI frames.",
        theme_assets=generated, texture_sources={"washi_sha256":digest(args.washi), "hinoki_sha256":digest(args.hinoki)}))
    notices = ["UKIYO-E GALLERY - INDEPENDENT ORBITUI COLLECTION", "",
        "All 27 museum images and their collection metadata are public domain / CC0 1.0.", CC0,
        "Rights were checked per object via each museum's API; evidence, URLs and source hashes are in provenance.json.",
        "Museum names identify sources, not endorsements. No museum logos are included.",
        "This is not AndyHazz's Ko-fi pack. No files, frames, textures or descriptions from that pack were used.",
        "The Swedish commentaries are AI-assisted OrbitUI editorial summaries of the cited museum sources, not verbatim museum texts.",
        "Supplementary sources may describe another impression or a related work; dimensions and dates always belong to the image's own museum record.",
        "Washi and wood materials were originally generated with the built-in image_gen tool; details in texture-prompts.json.",
        "Original frames, notes and generated materials: CC0 1.0 to the extent rights exist.", "",
        *[f"{name}: {policy}" for name, policy in MUSEUMS.values()], ""]
    for a in assets:
        notices += [a["file"], a["artist"], a["title"], a["date"], a["medium"],
                    a["measurements"], a["museum_name"] + ", " + a["accession"], a["credit"], a["object_url"],
                    "Commentary sources: " + "; ".join(a["note_sources"]), "CC0 1.0 (museum image); original OrbitUI summary", ""]
    (PACK / "ATTRIBUTION.txt").write_text("\n".join(notices), encoding="utf-8")
    preview(assets)
    contact_sheet(assets)
    # Keep the installer's explicit allowlist in sync with the produced pack.
    files = sorted(p.relative_to(PACK).as_posix() for p in PACK.rglob("*") if p.is_file())
    lines = ["-- Generated by scripts/build-ukiyoe.py; museum originals never need runtime networking.",
             "local M = {}", f'M.pack = "{PACK_NAME}"', "M.packs = {", "    { name = M.pack, marker = \"ornament-ukiyoe-gallery-v1.installed\", files = {"]
    lines += ["        " + json.dumps(name) + "," for name in files]
    lines += ["    } },", "}", "", "function M.seed(root, ornaments)",
              '    local changed = require("core/orbitui_ornament_install").seed(root, ornaments.dir(), M.packs)',
              '    local updated = require("core/orbitui_ukiyoe_update").apply(root, ornaments.dir())',
              '    return changed or updated', "end", "", "return M", ""]
    (ROOT / "core/orbitui_ukiyoe_ornaments.lua").write_text("\n".join(lines))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--washi", type=Path, required=True)
    parser.add_argument("--hinoki", type=Path, required=True)
    build(parser.parse_args())
