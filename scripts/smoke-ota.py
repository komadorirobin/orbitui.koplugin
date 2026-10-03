#!/usr/bin/env python3
"""Exercise the packaged OTA payload with real KOReader SHA/archive code.

Usage: python3 scripts/smoke-ota.py ZIP REFERENCE_DIR [--live] [--base-zip OLD_ZIP]
The reference directory must contain ffi/{archiver,libarchive_h,sha2}.lua.
Uses system libarchive and LuaJIT; does not run KOReader UI or touch an install.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile


def lua(value):
    if isinstance(value, str):
        return '"' + "".join(f"\\{byte:03d}" for byte in value.encode("utf-8")) + '"'
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "nil"
    if isinstance(value, dict):
        return "{" + ",".join(f"[{lua(key)}]={lua(item)}" for key, item in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(lua(item) for item in value) + "}"
    return str(value)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("archive", type=Path)
parser.add_argument("references", type=Path)
parser.add_argument("--live", action="store_true")
parser.add_argument("--base-zip", type=Path, help="Use a real older release as the starting installation")
args = parser.parse_args()
archive, references = args.archive.resolve(), args.references.resolve()
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="orbitui-native-ota-") as directory:
    directory = Path(directory)
    with zipfile.ZipFile(archive) as source:
        # The input is our own sealed build; the actual installer is tested below.
        manifest_text = source.read("orbitui.koplugin/manifest.json").decode()
    with zipfile.ZipFile(args.base_zip or archive) as source:
        source.extractall(directory)
    install = directory / "orbitui.koplugin"
    if not args.base_zip:
        (install / "VERSION").write_text("0.1.0-alpha.1\n")
    base_version = (install / "VERSION").read_text().strip()
    fixture = {
        "root": str(install), "archive": str(archive), "references": str(references),
        "manifest_text": manifest_text, "manifest": json.loads(manifest_text),
        "checksum": archive.with_name(archive.name + ".sha256").read_text(),
        "size": archive.stat().st_size,
        "live": args.live, "base_version": base_version,
    }
    fixture_path = directory / "fixture.lua"
    fixture_path.write_text("return " + lua(fixture), encoding="ascii")
    subprocess.run(["luajit", "scripts/smoke-ota.lua", str(fixture_path)], cwd=root, check=True)
