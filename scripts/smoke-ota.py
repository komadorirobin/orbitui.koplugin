#!/usr/bin/env python3
"""Exercise the packaged OTA payload with real KOReader SHA/archive code.

Usage: python3 scripts/smoke-ota.py ZIP KOReader-base-reference-directory
The reference directory must contain ffi/{archiver,libarchive_h,sha2}.lua.
Uses system libarchive and LuaJIT; does not run KOReader UI or touch an install.
"""
import json
from pathlib import Path
import subprocess
import sys
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


archive, references = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="orbitui-native-ota-") as directory:
    directory = Path(directory)
    with zipfile.ZipFile(archive) as source:
        # The input is our own sealed build; the actual installer is tested below.
        source.extractall(directory)
        manifest_text = source.read("orbitui.koplugin/manifest.json").decode()
    install = directory / "orbitui.koplugin"
    (install / "VERSION").write_text("0.1.0-alpha.1\n")
    fixture = {
        "root": str(install), "archive": str(archive), "references": str(references),
        "manifest_text": manifest_text, "manifest": json.loads(manifest_text),
        "checksum": archive.with_name(archive.name + ".sha256").read_text(),
        "size": archive.stat().st_size,
    }
    fixture_path = directory / "fixture.lua"
    fixture_path.write_text("return " + lua(fixture), encoding="ascii")
    subprocess.run(["luajit", "scripts/smoke-ota.lua", str(fixture_path)], cwd=root, check=True)
