#!/usr/bin/env python3
"""Seal a git-archive runtime ZIP with an exact file inventory and SHA-256."""

import hashlib
import json
from pathlib import Path
import re
import sys
import zipfile

PREFIX = "orbitui.koplugin/"
ASSET = "orbitui.koplugin.zip"


def seal(path):
    with zipfile.ZipFile(path) as source:
        records = []
        seen = set()
        for item in source.infolist():
            assert item.filename.startswith(PREFIX), "Unexpected archive root"
            relative = item.filename[len(PREFIX):]
            assert "\\" not in relative and ":" not in relative, "Unsafe filename"
            assert all(not part.startswith(".") for part in relative.split("/") if part), "Unsafe filename"
            identity = relative.rstrip("/").lower()
            assert identity not in seen, "Duplicate/case-ambiguous archive path"
            seen.add(identity)
            mode = (item.external_attr >> 16) & 0o170000
            assert mode in (0, 0o040000, 0o100000), "Links/special files are not allowed"
            records.append((item, source.read(item)))
    files = {item.filename[len(PREFIX):]: data for item, data in records if not item.is_dir()}
    version = files["VERSION"].decode("ascii").strip()
    assert re.fullmatch(r"\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?", version), "Invalid version"
    assert "manifest.json" not in files, "Archive is already sealed"
    manifest = {
        "schema": 1, "bootstrap_api": 1, "version": version,
        "files": [{"path": name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                  for name, data in sorted(files.items())],
    }
    temporary = path.with_suffix(".tmp")
    with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as output:
        for item, data in records:
            output.writestr(item, data)
        entry = zipfile.ZipInfo(PREFIX + "manifest.json", records[0][0].date_time)
        entry.compress_type = zipfile.ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        output.writestr(entry, json.dumps(manifest, sort_keys=True, indent=2) + "\n")
    temporary.replace(path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    path.with_name(path.name + ".sha256").write_text(f"{digest}  {ASSET}\n", encoding="ascii")
    print(f"Sealed {version}: {len(files)} files; SHA-256 {digest}")


if __name__ == "__main__":
    seal(Path(sys.argv[1]))
