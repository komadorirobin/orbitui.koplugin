#!/usr/bin/env python3
"""Build data-only, independently versioned ornament releases. Never publishes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RELEASE = "https://github.com/komadorirobin/orbitui.koplugin/releases/download/"
HELD = "fc6d71bd1538bee9a569a9838b7a00c5374469f0cc8efad3c70674a20c286bb9"
EXTS = {".png", ".jpg", ".jpeg", ".json", ".txt", ".md"}
NOTICES = {"authors": ["THOMAS-MANN-SEITZ.txt", "AUTHOR-SCULPTURES.txt", "KAFKA-KIELCE.txt"],
           "authors-ii": ["ERNEST-HEMINGWAY.txt"]}


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def localize(metadata, folder, translations):
    for name, record in metadata.items():
        source = record.get("info")
        if not source:
            continue
        key = folder + "/" + name
        text = translations[key]
        assert text["source_sha256"] == digest(source.encode()), f"Review stale translations: {key}"
        assert source in (text["en"], text["sv"]), f"Keep the original caption: {key}"
        source_links = set(re.findall(r"https?://\S+", source))
        for language in ("en", "sv"):
            value = text[language]
            assert isinstance(value, str) and 0 < len(value.encode()) <= 4000, f"Invalid caption: {key}/{language}"
            assert set(re.findall(r"https?://\S+", value)) == source_links, f"Changed source/licence links: {key}/{language}"
            record["info_" + language] = value
        record["info_source"] = source
    return metadata


def build(output, revision, previous=None, baseline=False, root=ROOT):
    definitions = json.loads((root / "addons/packs.json").read_text())
    translations = json.loads((root / "addons/ornament-translations.json").read_text())
    old = {p["id"]: p for p in (previous or {}).get("packs", [])}
    assert revision > (previous or {}).get("revision", 0), "Catalog revision must increase"
    output.mkdir(parents=True, exist_ok=True)
    catalog = {"schema": 1, "api": 1, "revision": revision, "packs": []}
    legacy = {"schema": 1, "packs": {}}
    for definition in definitions["packs"]:
        pack = dict(definition)
        files, defaults, payload = [], {}, {}
        for folder in pack["folders"]:
            for source in sorted((root / "assets/ornaments" / folder).rglob("*")):
                assert not source.is_symlink(), source
                if not source.is_file():
                    continue
                assert source.suffix.lower() in EXTS, source
                name = source.relative_to(root / "assets/ornaments").as_posix()
                data = source.read_bytes()
                if source.name == "ornaments.json":
                    data = encoded(localize(json.loads(data), folder, translations))
                assert digest(data) != HELD, "Artwork release hold"
                assert len(data) <= 16 * 1024 * 1024
                payload[name] = data
                files.append({"path": name, "size": len(data), "sha256": digest(data)})
                if source.name == "ornaments.json":
                    defaults[name] = json.loads(data)
        manifest = {"schema": 1, "api": 1, "id": pack["id"], "version": pack["version"],
                    "folders": pack["folders"], "files": files, "defaults": defaults,
                    "bindings": pack.pop("bindings", {})}
        for notice in NOTICES.get(pack["id"], []):
            assert any(n.endswith("/" + notice) for n in payload), f"Missing rights notice: {notice}"
        # Fixed timestamps/order/compression make unchanged versions byte-identical.
        filename = f'{pack["id"]}-{pack["version"]}.zip'
        archive = output / filename
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for name, data in sorted({"manifest.json": encoded(manifest), **payload}.items()):
                info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                z.writestr(info, data, compresslevel=9)
        data = archive.read_bytes()
        pack.update(size=len(data), sha256=digest(data),
                    url=RELEASE + f"ornaments-{revision}/" + filename)
        prior = old.get(pack["id"])
        if prior:
            assert pack["version"] >= prior["version"], "Pack downgrade"
            assert set(prior["folders"]) <= set(pack["folders"]), "Keep compatibility folders"
            if pack["version"] == prior["version"]:
                assert pack["sha256"] == prior["sha256"], "Changed pack requires a version bump"
                pack["url"] = prior["url"]
        preview = pack.pop("preview") or next(n for n in payload if n.lower().endswith(".png"))
        preview_data = payload[preview]
        preview_name = f'{pack["id"]}-{pack["version"]}-preview.png'
        (output / preview_name).write_bytes(preview_data)
        pack["preview"] = {"url": RELEASE + f"ornaments-{revision}/" + preview_name,
                           "size": len(preview_data), "sha256": digest(preview_data)}
        catalog["packs"].append(pack)
        legacy["packs"][pack["id"]] = manifest
    (output / "ornaments-catalog.json").write_bytes(encoded(catalog))
    (output / "SHA256SUMS").write_text("".join(
        f"{digest(p.read_bytes())}  {p.name}\n" for p in sorted(output.iterdir())
        if p.is_file() and p.name != "SHA256SUMS"))
    if baseline:
        destination = root / "assets/addons"
        destination.mkdir(parents=True, exist_ok=True)
        frozen = destination / "legacy-v1.json"
        assert not frozen.exists() or frozen.read_bytes() == encoded(legacy), "Migration baseline is frozen"
        frozen.write_bytes(encoded(legacy))
        # No unpublished download links in the runtime. Refresh discovers releases.
        (destination / "catalog.json").write_bytes(encoded(definitions))
    return catalog


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist/ornaments")
    parser.add_argument("--revision", type=int, required=True)
    parser.add_argument("--previous", type=Path)
    parser.add_argument("--baseline", action="store_true", help="Initial migration baseline only; never regenerate after release")
    args = parser.parse_args()
    build(args.output, args.revision, json.loads(args.previous.read_text()) if args.previous else None,
          args.baseline)
