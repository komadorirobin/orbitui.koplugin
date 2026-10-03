import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/vector-icons"
spec = importlib.util.spec_from_file_location("vector_build", ROOT / "scripts/build-vector-icons.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class VectorAssetsTest(unittest.TestCase):
    def test_pinned_inventory_and_checksums(self):
        manifest = json.loads((BASE / "generated.json").read_text())
        selection = json.loads((BASE / "selection.json").read_text())
        expected = set()
        inputs = set()
        for pack, source, style in builder.PACKS:
            config = selection[source]
            self.assertEqual(manifest["sources"][source]["commit"], config["commit"])
            self.assertRegex(config["commit"], r"^[0-9a-f]{40}$")
            names = []
            for group, icons in config["groups"].items():
                self.assertIn(group, ("Reading", "Navigation", "System", "Tools"))
                for path, _ in icons:
                    name = builder.re.sub(r"[^a-z0-9]+", "-", path.split("/")[-1].lower()).strip("-")
                    names.append(name)
                    upstream = f"icons/SVG/{style}/{path}.svg" if style else f"icons/outline/{path}.svg"
                    key = f"{source}:{upstream}"
                    inputs.add(key)
                    self.assertRegex(manifest["inputs"][key]["git_blob"], r"^[0-9a-f]{40}$")
                    self.assertRegex(manifest["inputs"][key]["sha256"], r"^[0-9a-f]{64}$")
            if source == "solar":
                names.insert(0, "manga")
            self.assertEqual(len(names), len(set(names)))
            self.assertEqual({p.stem for p in (BASE / pack).glob("*.svg")}, set(names))
            expected.update(f"assets/vector-icons/{pack}/{name}.svg" for name in names)
            expected.add(f"core/orbitui_{pack.replace('-', '_')}_catalogue.lua")
        for path in (BASE / "custom").glob("*.svg"):
            key = str(path.relative_to(ROOT))
            inputs.add(key)
            self.assertEqual(manifest["inputs"][key]["sha256"], builder.sha(path.read_bytes()))
        self.assertEqual(set(manifest["inputs"]), inputs)
        expected.add("assets/vector-icons/TABLER-LICENSE.txt")
        self.assertEqual(set(manifest["outputs"]), expected)
        for path, digest in manifest["outputs"].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
        self.assertLess(sum((ROOT / p).stat().st_size for p in expected), 1_000_000)

    def test_licenses_and_modification_attribution(self):
        self.assertIn("Attribution 4.0 International", (BASE / "SOLAR-LICENSE.txt").read_text())
        self.assertIn("MIT License", (BASE / "TABLER-LICENSE.txt").read_text())
        notice = (BASE / "NOTICE.txt").read_text()
        for text in ("480 Design", "Pawel Kuna", "CC BY 4.0", "rescaled/repositioned", "OrbitUI"):
            self.assertIn(text, notice)

    def test_svg_subset_and_native_styles(self):
        for path in BASE.rglob("*.svg"):
            data = path.read_bytes()
            builder.normalized_svg(data)
            self.assertNotIn(b"currentColor", data)
            self.assertNotIn(b"<text", data)
            if path.parent.name == "solar-outline":
                self.assertNotIn(b"opacity=", data, path)
            if path.parent.name == "tabler":
                self.assertEqual(ET.fromstring(data).get("stroke-width"), "2")
        mono = (BASE / "solar-outline/manga.svg").read_bytes()
        duo = (BASE / "solar-duotone/manga.svg").read_bytes()
        self.assertEqual(duo.replace(b' opacity="0.5"', b""), mono)
        self.assertEqual(mono, builder.normalized_svg((BASE / "custom/manga-outline.svg").read_bytes()))
        self.assertEqual(duo, builder.normalized_svg((BASE / "custom/manga-duotone.svg").read_bytes()))

    def test_svg_sanitizer_rejects_nonlocal_content(self):
        for child in ('<image href="https://example.com"/>', '<text>font dependency</text>',
                      '<script>alert(1)</script>', '<path fill="url(https://example.com)"/>',
                      '<path onload="alert(1)"/>'):
            with self.assertRaises(ValueError):
                builder.normalized_svg((f'<svg xmlns="{builder.NS}" viewBox="0 0 24 24">'
                                        + child + '</svg>').encode())


if __name__ == "__main__":
    unittest.main()
