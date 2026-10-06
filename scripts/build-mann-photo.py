#!/usr/bin/env python3
"""Import the reviewed Ahrens photographic cutout and hash-scoped credits.

Use --cutouts with build-sculpture-cutouts.py's output. The v4 migration
baseline includes published alpha.23 defaults; later builds retain it.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Authors"
ART = ROOT / "scripts/artwork/mann-seitz.json"
MIGRATION = ROOT / "assets/ornament-updates/mann-photo-v4.json"
PREVIOUS_RELEASE = "v0.1.0-alpha.23"
NOTICE = "THOMAS-MANN-SEITZ.txt"
RETIRED_HASH = "fc6d71bd1538bee9a569a9838b7a00c5374469f0cc8efad3c70674a20c286bb9"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cutouts", type=Path)
    args = parser.parse_args()
    if args.cutouts:
        assets = json.loads((args.cutouts / "provenance.json").read_text())
        assert len(assets) == 1 and assets[0]["file"] == "Thomas Mann.png"
        art = assets[0]
        assert digest(args.cutouts / art["file"]) == art["sha256"]
        if not MIGRATION.exists():
            def published(path):
                return subprocess.check_output([
                    "git", "show", f"{PREVIOUS_RELEASE}:{path.relative_to(ROOT).as_posix()}"
                ], cwd=ROOT)
            old = json.loads(published(ROOT / "assets/ornament-updates/mann-photo-v3.json"))
            previous_art = json.loads(published(ART))
            previous = json.loads(published(PACK / "ornaments.json"))[art["file"]]
            assert previous_art["sha256"] == old["new_sha256"]
            assert hashlib.sha256(published(PACK / art["file"])).hexdigest() == old["new_sha256"]
            documents = old["documents"]
            for name in (*documents, NOTICE):
                values = documents.setdefault(name, [])
                value = hashlib.sha256(published(PACK / name)).hexdigest()
                if value not in values:
                    values.append(value)
            write_json(MIGRATION, {
                "old_sha256": old["old_sha256"] + [old["new_sha256"]],
                "new_sha256": art["sha256"],
                "old_info": list(dict.fromkeys(old["old_info"] + [previous["info"]])),
                "old_placements": old["old_placements"] + [previous_art["placement"]],
                "documents": documents,
            })
        assert json.loads(MIGRATION.read_text())["new_sha256"] == art["sha256"]
        shutil.copyfile(args.cutouts / art["file"], PACK / art["file"])
        write_json(ART, art)
    art = json.loads(ART.read_text())
    assert art["kind"] == "Masked original photograph"
    assert digest(PACK / art["file"]) == art["sha256"]
    sections = [
        "THOMAS MANN / GUSTAV SEITZ - PAULINE AHRENS PHOTOGRAPHIC CUTOUT",
        "These credits apply ONLY to PNG SHA-256 " + art["sha256"]
        + ". They do not license custom artwork or the retired AI-assisted image.",
        art["reference_credit"],
        "Photograph and adapted photograph: " + art["artwork_license"] + "\n" + art["license_url"],
        "Changes by OrbitUI contributors: background masked out. " + art["framing"] + " Proportional resizing only. Original photo colours and portrait details are preserved; no generative reconstruction or retouching. This is a new photographic cutout, not a relicensing of the previous Molgreen photograph or the held image_gen adaptation. No endorsement is implied.",
        "Sources:\n" + "\n".join(art["references"])
        + "\nOriginal photograph: " + art["source_image"],
        "Source SHA-256: " + art["source_sha256"]
        + "\nReviewed mask SHA-256: " + art["mask_sha256"],
        "SCULPTURE RIGHTS / REVIEW BASIS (2026-10-06)\n" + art["rights_basis"]
        + " This is the project's documented basis for this photographic depiction, not legal advice or confirmation of permission from the Gustav Seitz Foundation. The photo license does not extinguish sculpture rights.",
        "RETIRED IMAGE - RELEASE HOLD REMAINS\nThe superseded Pauline Ahrens/image_gen adaptation (PNG SHA-256 "
        + RETIRED_HASH + ") remains uncleared. It is not bundled in the current tree. Do not push that bitmap, including commits containing it, or publish an OTA with it. Replacing the tip's image does not sanitize earlier Git history. Keep any necessary historical backup local; prepare a public history without the held bitmap before releasing. No rights-holder permission has been requested or obtained for that adaptation.",
    ]
    (PACK / NOTICE).write_text("\n\n".join(sections) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
