#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
LUA="${LUA:-lua}"
export LUA
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_upstream_watch.py' -v
"$LUA" scripts/module-map.lua --check
luajit scripts/syntax.lua
for test_file in tests/test_*.lua; do
    "$LUA" "$test_file"
done
sh components/bookshelf/tests/run.sh
(
    cd components/simpleui
    for test_file in tests/_test_*.lua; do
        "$LUA" "$test_file"
    done
)
