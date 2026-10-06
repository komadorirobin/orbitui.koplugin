#!/usr/bin/env python3
"""Build the additive Authors II pack without rewriting historical migrations."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Authors II"
ART = ROOT / "scripts/artwork"
spec = importlib.util.spec_from_file_location("author_info", ROOT / "scripts/build-author-info.py")
author_info = importlib.util.module_from_spec(spec)
spec.loader.exec_module(author_info)


def build(cutouts=None):
    provenance = ART / "author-additions.json"
    assets = json.loads(((cutouts / "provenance.json") if cutouts else provenance).read_text())
    bios = json.loads((ART / "author-addition-biographies.json").read_text())
    assert {a["file"] for a in assets} == set(bios)
    PACK.mkdir(parents=True, exist_ok=True)
    metadata = {}
    notices = ["AUTHORS II - PHOTOGRAPHIC CUTOUTS",
               "These credits apply ONLY to the PNG SHA-256 values below, not to custom replacements.",
               "Original photo pixels: background masking and proportional resizing only. No AI-generated sculpture details or colour changes.",
               "Photographs and sculptures have separate rights. No endorsement or worldwide sculpture-rights waiver is implied.",
               "Public redistribution review is still required; see the per-image rights basis. The existing Mann release hold also remains.",
               "ShareAlike applies to the Svevo adaptation, not the entire collection. Source photographs are not bundled."]
    for asset in assets:
        name = asset["file"]
        source = (cutouts or PACK) / name
        assert hashlib.sha256(source.read_bytes()).hexdigest() == asset["sha256"], name
        if cutouts:
            shutil.copyfile(source, PACK / name)
        info = author_info.info_text(bios[name], asset["info"])
        assert len(info.encode()) <= 4000, name
        metadata[name] = dict(asset["placement"], pad=.035, night="off", mirror="off", tap="zoom", info=info)
        notices.append("\n".join([
            name, asset["reference_credit"], "Photograph/adaptation: " + asset["artwork_license"],
            asset["license_url"], "Separate rights basis: " + asset["rights_basis"],
            *asset["references"], "Original photograph: " + asset["source_image"],
            "Source SHA-256: " + asset["source_sha256"], "PNG SHA-256: " + asset["sha256"],
        ]))
        print(name, len(info.encode()), "info bytes")
    if cutouts:
        author_info.write_json(provenance, assets)
    author_info.write_json(PACK / "ornaments.json", metadata)
    author_info.write_json(PACK / "prompts.json", {
        "mode": "Masked original photographs; no generative image prompts.",
        "tool": "scripts/build-sculpture-cutouts.py --spec scripts/artwork/sculpture-additions.json",
        "assets": assets,
    })
    (PACK / "ATTRIBUTION.txt").write_text("\n\n".join(notices) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cutouts", type=Path, help="Import reviewed PNGs and provenance from this build output")
    build(parser.parse_args().cutouts)
