#!/usr/bin/env python3
"""Static search vocabulary for retained native Bookshelf controls.

No Lua/menu/credential/provider evaluation. The small extractor indexes gettext
literal phrases (including adjacent literal concatenation), not preference
values. Search opens the owning settings section; callbacks are never indexed.
Run with --check after component updates. Generated data stays in the existing
adapter to preserve the installed API 1 file-count budget.
"""
import argparse
from pathlib import Path
import re
import sys
import json

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "adapters/orbitui_settings.lua"
BEGIN = "-- BEGIN GENERATED SETTINGS SEARCH TERMS"
END = "-- END GENERATED SETTINGS SEARCH TERMS"
SOURCES = ("bookshelf_settings.lua", "bookshelf_hero_line_editor.lua", "bookshelf_theme_menu.lua")


def literal(token):
    # Lua's hex escapes encode UTF-8 BYTES, not Latin-1 Unicode characters.
    raw, out, index = token[1:-1], bytearray(), 0
    escapes = {"n": 10, "r": 13, "t": 9, "b": 8, "f": 12, "v": 11, "a": 7, '"': 34, "\\": 92}
    while index < len(raw):
        char = raw[index]
        if char != "\\":
            out.extend(char.encode("utf-8")); index += 1; continue
        index += 1
        char = raw[index]
        if char == "x":
            out.append(int(raw[index + 1:index + 3], 16)); index += 3
        elif char.isdigit():
            number = re.match(r"\d{1,3}", raw[index:]).group()
            out.append(int(number)); index += len(number)
        else:
            out.append(escapes[char]); index += 1
    return out.decode("utf-8")


def terms():
    result = {}
    for filename in SOURCES:
        source = (ROOT / "components/bookshelf/lib" / filename).read_text()
        owner = "bookshelf_advanced"
        functions = list(re.finditer(r"^function Settings[:.]([^\s(]+)", source, re.M))
        for match in re.finditer(r'_\(\s*((?:"(?:\\.|[^"\\])*"\s*(?:\.\.\s*)?)+)\)', source):
            if filename == "bookshelf_theme_menu.lua":
                owner = "themes"
            elif filename == "bookshelf_hero_line_editor.lua":
                owner = "panel"
            else:
                name = next((f.group(1).lower() for f in reversed(functions) if f.start() < match.start()), "")
                if any(k in name for k in ("hardcover",)): owner = "hardcover"
                elif any(k in name for k in ("hero", "token")): owner = "panel"
                elif any(k in name for k in ("wallpaper", "plank", "ornament", "color", "scrim", "panelrow", "lightdark")): owner = "themes"
                elif any(k in name for k in ("performance", "covercache")): owner = "safety"
                elif any(k in name for k in ("whilereading", "reader", "behaviour")): owner = "reader"
                elif any(k in name for k in ("library", "latestdepth", "imagelibrary")): owner = "maintenance"
                elif any(k in name for k in ("font", "textsize")): owner = "bookshelf_text"
                elif any(k in name for k in ("cover", "badge", "pagecount")): owner = "covers"
                else: owner = "bookshelf_advanced"
            pieces = re.findall(r'"(?:\\.|[^"\\])*"', match.group(1))
            text = "".join(literal(piece) for piece in pieces)
            if 2 <= len(text) <= 140 and "%" not in text and text.strip() == text:
                result.setdefault(owner, set()).add(text)
    return {key: sorted(values) for key, values in sorted(result.items())}


def generated():
    lines = [BEGIN, "local native_terms = {"]
    for owner, values in terms().items():
        lines.append(f'    {owner} = {{')
        lines.extend("        " + json.dumps(value, ensure_ascii=False) + "," for value in values)
        lines.append("    },")
    return "\n".join(lines + ["}", END])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", action="store_true")
    options = parser.parse_args()
    if options.check:
        source = ADAPTER.read_text()
        block = re.search(re.escape(BEGIN) + ".*?" + re.escape(END), source, re.S)
        if not block or block.group() != generated():
            sys.exit("Settings search vocabulary is stale; regenerate the adapter's marked block.")
        print(f"Settings search: {sum(map(len, terms().values()))} native phrases verified")
    elif options.json:
        print(json.dumps(terms(), ensure_ascii=False))
    else:
        print(generated())
