import hashlib
import json
from pathlib import Path
import struct
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/material-symbols"


class MaterialAssetsTest(unittest.TestCase):
    def test_generated_inventory_and_license(self):
        manifest = json.loads((ASSETS / "generated.json").read_text())
        selection = json.loads((ASSETS / "selection.json").read_text())
        names = [name for group in selection["groups"].values() for name in group]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(manifest["icons"], len(names))
        self.assertEqual(set(manifest["files"]), {"MaterialSymbolsRounded.ttf"} |
                         {"icons/" + name + ".svg" for name in names})
        for name, digest in manifest["files"].items():
            self.assertEqual(hashlib.sha256((ASSETS / name).read_bytes()).hexdigest(), digest, name)
        self.assertIn("Apache License", (ASSETS / "LICENSE").read_text())
        self.assertIn(selection["upstream_commit"], (ASSETS / "NOTICE.txt").read_text())
        self.assertEqual(selection["axes"], {"FILL": 0, "GRAD": 0, "opsz": 24, "wght": 500})

    def test_static_true_type_with_manga_in_cmap(self):
        data = (ASSETS / "MaterialSymbolsRounded.ttf").read_bytes()
        self.assertLess(len(data), 100_000)
        self.assertEqual(data[:4], b"\0\1\0\0")
        tables = {}
        for i in range(struct.unpack_from(">H", data, 4)[0]):
            tag, _, offset, size = struct.unpack_from(">4sIII", data, 12 + i * 16)
            tables[tag] = data[offset:offset + size]
        self.assertNotIn(b"fvar", tables)
        cmap = tables[b"cmap"]
        found = False
        for i in range(struct.unpack_from(">H", cmap, 2)[0]):
            platform, encoding, offset = struct.unpack_from(">HHI", cmap, 4 + i * 8)
            if platform == 3 and encoding == 1:
                sub = cmap[offset:]
                self.assertEqual(struct.unpack_from(">H", sub)[0], 4)
                count = struct.unpack_from(">H", sub, 6)[0] // 2
                ends = struct.unpack_from(">" + "H" * count, sub, 14)
                starts = struct.unpack_from(">" + "H" * count, sub, 16 + count * 2)
                for code in (0xF5E3, 0xF5DD):
                    self.assertTrue(any(a <= code <= b for a, b in zip(starts, ends)))
                found = True
        self.assertTrue(found, "Windows Unicode cmap missing")

    def test_svg_outlines_are_local_monochrome_and_have_a_consistent_canvas(self):
        for path in (ASSETS / "icons").glob("*.svg"):
            svg = ET.fromstring(path.read_bytes())
            self.assertEqual(svg.attrib["viewBox"], "0 0 960 960")
            self.assertEqual(len(svg), 1)
            outline = svg[0]
            self.assertEqual(outline.tag, "{http://www.w3.org/2000/svg}path")
            self.assertEqual(outline.attrib["fill"], "#000000")
            self.assertEqual(outline.attrib["transform"], "translate(0 960) scale(1 -1)")
            self.assertTrue(outline.attrib["d"])
            self.assertFalse("href" in path.read_text())


if __name__ == "__main__":
    unittest.main()
