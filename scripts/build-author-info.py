#!/usr/bin/env python3
"""Build offline author cards with versioned, per-artwork credits."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "assets/ornament-updates/author-info-v1.json"
SOURCE_COMMIT = "d224901dcddbcc0d457a801058437cd20d2c0217"
CONTENT = ROOT / "scripts/artwork/author-biographies.json"
CREDIT = "Text: OrbitUI, AI-assisterad svensk sammanfattning av källorna nedan. Inte källornas originaltext."
ART_HEADING = "Om bysten / bildkrediter:"
KAFKA = ROOT / "scripts/artwork/kafka-kielce.json"


def artwork_credit(name, original):
    if name == "Franz Kafka.png":
        return json.loads(KAFKA.read_text(encoding="utf-8"))["info"]
    return original


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
            info = info_text(bios[name], artwork_credit(name, before["info"]))
            assert len(info.encode("utf-8")) <= 4000, (name, "Native info byte limit exceeded")
            metadata[name]["info"] = info
            print(f"{pack}/{name}: {len(info.encode('utf-8'))} bytes")
        write_json(path, metadata)

    kafka = json.loads(KAFKA.read_text(encoding="utf-8"))
    folder = ROOT / "assets/ornaments/Authors"
    assert hashlib.sha256((folder / kafka["file"]).read_bytes()).hexdigest() == kafka["sha256"]
    path = folder / "ornaments.json"
    metadata = json.loads(path.read_text(encoding="utf-8"))
    metadata[kafka["file"]].update(kafka["placement"])
    write_json(path, metadata)
    path = folder / "prompts.json"
    prompts = json.loads(path.read_text(encoding="utf-8"))
    prompts["assets"] = [kafka if a["file"] == kafka["file"] else a for a in prompts["assets"]]
    write_json(path, prompts)

    migration = ROOT / "assets/ornament-updates/kafka-kielce-v1.json"
    if not migration.exists():
        # Freeze both the published caption and the local, unpublished biography.
        commits = [SOURCE_COMMIT, "67c4219f"]
        old_info, documents = [], {n: [] for n in ("README.txt", "ATTRIBUTION.txt", "prompts.json")}
        for commit in commits:
            def previous(name):
                return subprocess.check_output([
                    "git", "show", f"{commit}:assets/ornaments/Authors/{name}"
                ], cwd=ROOT)
            old_info.append(json.loads(previous("ornaments.json"))[kafka["file"]]["info"])
            for name, hashes in documents.items():
                digest = hashlib.sha256(previous(name)).hexdigest()
                if digest not in hashes:
                    hashes.append(digest)
        write_json(migration, {
            "old_sha256": "cf92760b445de7cca2ae7aaf44fabf745f6f9f25268ac8025397fd556a7969c9",
            "new_sha256": kafka["sha256"], "old_info": old_info,
            "old_placement": {"scale": 0.996, "anchor": "bottom", "lift": -0.01},
            "documents": documents,
        })


if __name__ == "__main__":
    build()
