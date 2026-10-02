#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
    printf '%s\n' 'Commit the tested source before packaging.' >&2
    exit 1
fi
lua scripts/module-map.lua --check
mkdir -p dist
git archive --format=zip --prefix=orbitui.koplugin/ -o dist/orbitui.koplugin.zip HEAD
python3 scripts/release-package.py dist/orbitui.koplugin.zip
unzip -t dist/orbitui.koplugin.zip > /dev/null
lua scripts/check-package.lua dist/orbitui.koplugin.zip
printf '%s\n' 'Created dist/orbitui.koplugin.zip and its OTA checksum (preview).'
shasum -a 256 dist/orbitui.koplugin.zip
