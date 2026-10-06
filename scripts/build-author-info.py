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
MANN = ROOT / "scripts/artwork/mann-seitz.json"
SCULPTURES = ROOT / "scripts/artwork/author-sculptures.json"
RETIRED = {"Authors": {"Clarice Lispector.png"}}


def artwork_credit(name, original):
    if name == "Franz Kafka.png":
        return json.loads(KAFKA.read_text(encoding="utf-8"))["info"]
    if name == "Thomas Mann.png":
        return json.loads(MANN.read_text(encoding="utf-8"))["info"]
    for asset in json.loads(SCULPTURES.read_text(encoding="utf-8")):
        if name == asset["file"]:
            return asset["info"]
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
        retired = RETIRED.get(pack, set())
        assert set(metadata) == set(previous["metadata"]) - retired
        for name, before in previous["metadata"].items():
            if name in retired:
                continue
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

    mann = json.loads(MANN.read_text(encoding="utf-8"))
    assert hashlib.sha256((folder / mann["file"]).read_bytes()).hexdigest() == mann["sha256"]
    path = folder / "ornaments.json"
    metadata = json.loads(path.read_text(encoding="utf-8"))
    metadata[mann["file"]].update(mann["placement"])
    write_json(path, metadata)
    path = folder / "prompts.json"
    prompts = json.loads(path.read_text(encoding="utf-8"))
    prompts["assets"] = [mann if a["file"] == mann["file"] else a for a in prompts["assets"]]
    write_json(path, prompts)

    sculptures = json.loads(SCULPTURES.read_text(encoding="utf-8"))
    metadata = json.loads((folder / "ornaments.json").read_text())
    for asset in sculptures:
        assert hashlib.sha256((folder / asset["file"]).read_bytes()).hexdigest() == asset["sha256"]
        metadata[asset["file"]].update(asset["placement"])
    write_json(folder / "ornaments.json", metadata)
    replacements = {a["file"]: a for a in sculptures}
    prompts = json.loads((folder / "prompts.json").read_text())
    prompts["mode"] = "Mixed per-asset provenance: seven masked photographs; only Kafka retains an AI-assisted cutout."
    prompts["tool"] = "See each asset: scripts/build-sculpture-cutouts.py or OpenAI built-in image_gen."
    prompts["assets"] = [replacements.get(a["file"], a) for a in prompts["assets"]]
    write_json(folder / "prompts.json", prompts)

    migration = ROOT / "assets/ornament-updates/author-sculptures-v1.json"
    if not migration.exists():
        commits = [SOURCE_COMMIT, "67c4219f", "568fc943", "d9e27ea8"]
        documents = {n: [] for n in ("README.txt", "ATTRIBUTION.txt", "prompts.json")}
        captions = {a["file"]: [] for a in sculptures}
        for commit in commits:
            def previous(name):
                return subprocess.check_output([
                    "git", "show", f"{commit}:assets/ornaments/Authors/{name}"
                ], cwd=ROOT)
            old_metadata = json.loads(previous("ornaments.json"))
            for name, values in captions.items():
                if old_metadata[name]["info"] not in values:
                    values.append(old_metadata[name]["info"])
            for name, values in documents.items():
                digest = hashlib.sha256(previous(name)).hexdigest()
                if digest not in values:
                    values.append(digest)
        assets = []
        for asset in sculptures:
            name = asset["file"]
            assets.append({"file": name,
                           "old_sha256": hashlib.sha256(previous(name)).hexdigest(),
                           "new_sha256": asset["sha256"], "old_info": captions[name],
                           "old_placement": {k: old_metadata[name][k] for k in ("scale", "anchor", "lift")}})
        write_json(migration, {"source_commits": commits, "assets": assets, "documents": documents})

    notices = ["AUTHOR SCULPTURES - PHOTOGRAPHIC CUTOUTS",
               "These credits apply ONLY to the PNG SHA-256 values listed below, not to custom replacements.",
               "Photographs and sculptures have separate rights. No endorsement or worldwide sculpture-rights waiver is implied.",
               "Changes by OrbitUI: background alpha masks and proportional resizing only; no generated anatomy, recolouring or invented plinths.",
               "Source photos are not bundled. Reviewed masks and source hashes are in scripts/artwork/.",
               "ShareAlike applies to the adapted images where specified, not to the entire collection."]
    for asset in sculptures:
        notices.append("\n".join([asset["file"], asset["reference_credit"],
                                  "Photograph/adaptation: " + asset["artwork_license"], asset["license_url"],
                                  "Separate rights basis: " + asset["rights_basis"],
                                  *asset["references"], "Original photograph: " + asset["source_image"],
                                  "Source SHA-256: " + asset["source_sha256"],
                                  "PNG SHA-256: " + asset["sha256"]]))
    notices.append("Sculpture-rights references (not additional photograph licenses):\n"
                   "UK CDPA section 62: https://www.legislation.gov.uk/ukpga/1988/48/section/62\n"
                   "Poland: https://commons.wikimedia.org/wiki/Commons:Copyright_rules_by_territory/Poland#Freedom_of_panorama\n"
                   "Switzerland: https://www.ige.ch/fileadmin/user_upload/schuetzen/urheberrecht/e/Public_Domain_Fact_Sheet_EN_04.2020.pdf")
    (folder / "AUTHOR-SCULPTURES.txt").write_text("\n\n".join(notices) + "\n", encoding="utf-8")

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
