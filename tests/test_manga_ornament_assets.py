import hashlib
import json
from pathlib import Path
import struct
import unittest
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Manga"
HASHES = {
    "Kaneda Motorcycle.png": "84228bbb148dcbfa254ee1fbb5a4cb55ea2d9372cdf5a468b6ee40b16a94b169",
    "Walking Mushroom.png": "2538c61741cd32657e180d91c79e19af354c9a5a96a9df63fdca2ee93ff34b5a",
    "Apothecary Mortar.png": "7390228f5552cdfebb8c48bc24b66bce072e20096a09e3ff3dd3d17bb0ea17e1",
}


class MangaOrnamentAssetsTests(unittest.TestCase):
    def test_original_rgba_bytes_and_generation_provenance(self):
        prompts = json.loads((PACK / "prompts.json").read_text())
        self.assertIn("built-in image_gen", prompts["tool"])
        self.assertEqual({a["file"] for a in prompts["assets"]}, set(HASHES))
        self.assertEqual({p.name for p in PACK.glob("*.png")}, set(HASHES))
        for asset in prompts["assets"]:
            with self.subTest(name=asset["file"]):
                data = (PACK / asset["file"]).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), HASHES[asset["file"]])
                self.assertEqual(asset["sha256"], HASHES[asset["file"]])
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                self.assertEqual(struct.unpack(">IIBB", data[16:26]),
                                 (asset["width"], asset["height"], 8, 6))
                self.assertLess(asset["width"] * asset["height"], 4_000_000)
                self.assertIn(b"c2pa", data)
                self.assertEqual(asset["references"], [])
                self.assertIn("transparent", asset["prompt"].lower())

    def test_native_placement_zoom_and_colour_defaults(self):
        metadata = json.loads((PACK / "ornaments.json").read_text())
        prompts = json.loads((PACK / "prompts.json").read_text())
        self.assertEqual(set(metadata), set(HASHES))
        for asset in prompts["assets"]:
            entry = metadata[asset["file"]]
            with self.subTest(name=asset["file"]):
                self.assertEqual(entry["anchor"], "bottom")
                self.assertEqual(entry["tap"], "zoom")
                self.assertEqual(entry["night"], "off")
                self.assertEqual(entry["mirror"], "off")
                self.assertTrue(.5 <= entry["scale"] <= 1)
                self.assertTrue(0 <= entry["pad"] <= .05)
                self.assertLessEqual(len(entry["info"].encode("utf-8")), 4000)
                self.assertIn("Original AI-generated", entry["info"])
                aspect = asset["width"] / asset["height"]
                # Native default width cap is one stand height times scale.
                height = min(.8 * entry["scale"], entry["scale"] / aspect)
                gap = height * (1 - asset["alpha_bbox_at_24"][3] / asset["height"]) + entry["lift"]
                self.assertTrue(0 <= gap <= .006, "visible feet must meet the plank")

    def test_character_inspiration_is_not_mislabelled_as_unrestricted_artwork(self):
        notes = (PACK / "ATTRIBUTION.txt").read_text()
        metadata = json.loads((PACK / "ornaments.json").read_text())
        for name in HASHES:
            self.assertIn(name, notes)
        for name in ("Kaneda Motorcycle.png", "Walking Mushroom.png"):
            self.assertIn("unofficial fan art", metadata[name]["info"])
            self.assertNotIn("CC BY", metadata[name]["info"])
            self.assertIn("no blanket license", metadata[name]["info"])
        self.assertIn("CC BY 4.0", metadata["Apothecary Mortar.png"]["info"])

    def test_preview_uses_the_production_files_and_placement_values(self):
        html = (ROOT / "docs/manga-ornaments-preview.html").read_text()
        metadata = json.loads((PACK / "ornaments.json").read_text())
        for name, entry in metadata.items():
            self.assertIn("../assets/ornaments/Manga/" + quote(name), html)
            self.assertIn('data-scale="' + str(entry["scale"]) + '"', html)
            self.assertIn("--lift:" + str(entry["lift"]), html)


if __name__ == "__main__":
    unittest.main()
