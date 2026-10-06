#!/usr/bin/env python3
"""Build offline author cards, retaining the original artwork credits verbatim."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "assets/ornament-updates/author-info-v1.json"
SOURCE_COMMIT = "d224901dcddbcc0d457a801058437cd20d2c0217"
CONTENT = ROOT / "scripts/artwork/author-biographies.json"
CREDIT = "Text: OrbitUI, AI-assisterad svensk sammanfattning av källorna nedan. Inte källornas originaltext."
ART_HEADING = "Om bysten / bildkrediter:"


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def info_text(bio, original):
    sources = "\n".join(f'{s["title"]}:\n{s["url"]}' for s in bio["sources"])
    return "\n\n".join([
        f'{bio["name"]} ({bio["years"]})', *bio["paragraphs"],
        "Centrala verk:\n" + bio["works"], CREDIT, "Källor:\n" + sources,
        ART_HEADING + "\n" + original,
    ])


def build():
    if not BASELINE.exists():
        packs = {}
        for pack in ("Modernists", "Authors"):
            def old(name):
                return subprocess.check_output([
                    "git", "show", f"{SOURCE_COMMIT}:assets/ornaments/{pack}/{name}"
                ], cwd=ROOT).decode("utf-8")
            packs[pack] = {"metadata": json.loads(old("ornaments.json")), "readme": old("README.txt")}
        write_json(BASELINE, {"source_commit": SOURCE_COMMIT, "packs": packs})
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    bios = json.loads(CONTENT.read_text(encoding="utf-8"))
    expected = {name for pack in baseline["packs"].values() for name in pack["metadata"]}
    assert set(bios) == expected
    for pack, previous in baseline["packs"].items():
        path = ROOT / "assets/ornaments" / pack / "ornaments.json"
        metadata = json.loads(path.read_text(encoding="utf-8"))
        assert set(metadata) == set(previous["metadata"])
        for name, before in previous["metadata"].items():
            info = info_text(bios[name], before["info"])
            assert len(info.encode("utf-8")) <= 4000, (name, "Native info byte limit exceeded")
            metadata[name]["info"] = info
            print(f"{pack}/{name}: {len(info.encode('utf-8'))} bytes")
        write_json(path, metadata)


if __name__ == "__main__":
    build()
