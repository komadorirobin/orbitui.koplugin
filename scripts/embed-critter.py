#!/usr/bin/env python3
"""Keep the API-1-compatible embedded Hazel bytes identical to upstream PNGs."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "components/simpleui/modules/critter/assets.lua"
PNG_DIR = ASSETS.parent / "assets/hazel"
START = "-- BEGIN ORBITUI EMBEDDED HAZEL\n"
END = "-- END ORBITUI EMBEDDED HAZEL"


def generated():
    files = sorted(PNG_DIR.glob("*.png"))
    assert len(files) == 12, "Review changed upstream moods before embedding"
    lines = ["local EMBEDDED_HAZEL = {"]
    for image in files:
        lines.append(f'    {image.stem} = "{image.read_bytes().hex()}",')
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    source = ASSETS.read_text()
    before, tail = source.split(START, 1)
    _, after = tail.split(END, 1)
    result = before + START + generated() + END + after
    if args.check:
        if source != result:
            raise SystemExit("Embedded Hazel differs from upstream; run scripts/embed-critter.py")
        print("All 12 embedded Hazel PNGs match the tracked upstream originals")
    else:
        ASSETS.write_text(result)


if __name__ == "__main__":
    main()
