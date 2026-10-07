import hashlib
import importlib.util
import json
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/vector-icons"
spec = importlib.util.spec_from_file_location("solar_pack", ROOT / "scripts/build-solar-pack.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class SolarPackTest(unittest.TestCase):
    def test_full_pinned_inventory_and_output_hashes(self):
        config = json.loads((BASE / "pxlflux-source.json").read_text())
        manifest = json.loads((BASE / "pxlflux-generated.json").read_text())
        self.assertEqual(manifest["source"], config)
        self.assertRegex(config["commit"], r"^[0-9a-f]{40}$")
        expected = {"assets/vector-icons/PXLFLUX-LICENSE.txt"}
        seen_inputs = {"LICENSE"}
        for pack, style in config["styles"].items():
            names = set()
            for section in config["sections"]:
                prefix = f"Solar {style}/{section['directory']} ({style})/"
                paths = [p for p in manifest["inputs"] if p.startswith(prefix)]
                self.assertEqual(len(paths), section["count"])
                for path in paths:
                    self.assertTrue(path.endswith(".svg"))
                    name = section["prefix"] + "-" + re.sub(r"[^a-z0-9]+", "-", Path(path).stem.lower()).strip("-")
                    self.assertNotIn(name, names)
                    names.add(name)
                    self.assertRegex(manifest["inputs"][path]["git_blob"], r"^[0-9a-f]{40}$")
                    self.assertRegex(manifest["inputs"][path]["sha256"], r"^[0-9a-f]{64}$")
                    seen_inputs.add(path)
            self.assertEqual(len(names), 160)
            self.assertEqual({p.name for p in (BASE / pack).iterdir()}, {n + ".svg" for n in names})
            expected.update(f"assets/vector-icons/{pack}/{n}.svg" for n in names)
            catalogue = f"core/orbitui_{pack.replace('-', '_')}_catalogue.lua"
            expected.add(catalogue)
            self.assertEqual(set(re.findall(r'name = "([^"]+)"', (ROOT / catalogue).read_text())), names)
        self.assertEqual(set(manifest["inputs"]), seen_inputs)
        self.assertEqual(set(manifest["outputs"]), expected)
        for path, digest in manifest["outputs"].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
        self.assertLess(sum((ROOT / path).stat().st_size for path in expected), 650_000)

    def test_static_svg_only_with_distinct_colour_and_mono_styles(self):
        for style, stroke in (("colour", "0.75"), ("mono", "1")):
            for path in (BASE / f"solar-{style}").glob("*.svg"):
                data = path.read_bytes()
                self.assertEqual(builder.vector.normalized_svg(data), data)
                self.assertNotIn(b"currentColor", data)
                self.assertNotIn(b"<text", data)
            icon = ET.parse(BASE / f"solar-{style}/pack-library.svg")
            paths = list(icon.iter("{http://www.w3.org/2000/svg}path"))
            self.assertTrue(paths)
            self.assertTrue(all(p.get("stroke-width") == stroke for p in paths))
            fills = {p.get("fill") for p in paths}
            self.assertEqual(fills, {"#FFD77F", "#FFE7B0"} if style == "colour" else {"none"})

    def test_attribution_and_no_installer_or_presets(self):
        license_text = (BASE / "PXLFLUX-LICENSE.txt").read_text()
        notice = (BASE / "NOTICE.txt").read_text()
        for value in ("pxlflux", "480 Design", "CC BY 4.0"):
            self.assertIn(value, license_text)
            self.assertIn(value, notice)
        for value in ("geometry, colours", "stroke widths are preserved", "installer", "pack.lua"):
            self.assertIn(value, notice)
        self.assertIn("https://creativecommons.org/licenses/by/4.0/", notice)
        self.assertIn("Attribution 4.0 International", (BASE / "SOLAR-LICENSE.txt").read_text())


if __name__ == "__main__":
    unittest.main()
