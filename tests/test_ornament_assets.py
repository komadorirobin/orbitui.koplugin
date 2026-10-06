import hashlib
import json
from pathlib import Path
import struct
import unittest
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Modernists"
HASHES = {
    "James Joyce.png": "fd0e35430db5fcb70dcbe5de222c50b448b8ffbc73e22cb5e7a2eb59fbd2e5b4",
    "Virginia Woolf.png": "8b8a1a3d57d2df298bf7896b770d941b34682fab81ed1823f69075af46a992fb",
}
AUTHOR_HASHES = {
    "August Strindberg.png": "719e860c41d8baddde7c91b6486e9500e713706a1e630a6c1a442947a50e96a8",
    "Stanislaw Lem.png": "6bca32b5582a15019fbefdddbb7bda1e11bac86458d7f34ba5aff10a544ad398",
    "Dylan Thomas.png": "5527a7d26c3210d95d3f2316f0766219b6c8f99f72a9a54c802a1069bb66ec3a",
    "Thomas Mann.png": "e584052943e66f9edc23622a48fc7f4f1c7482d306c4d8a080c74a896e6e68a7",
    "Fyodor Dostoevsky.png": "04c917132a05343545dc1f08d856f68e1b022c9fd2fbff5cb17f6f6df76f310a",
    "Knut Hamsun.png": "8559aafafe6dbe0010d361805ab65798d2e2d0a254960c71f196b7891ec0d7e7",
    "Clarice Lispector.png": "bee7a3d24770d1931d4144b3e5ad1c8b71beaac0d10b5acbf9f43d317524343a",
    "Robert Musil.png": "0c6d0b652b5e3405e4a4804900726b5aa3c1179d439d7d70d7e9288055590d44",
    "Franz Kafka.png": "1eb6d88d1c00f2b7ecb932146798e056e02bf5e2ed54b77dee702d2056a6202e",
}
JAPAN_HASHES = {
    "Pine Bonsai.png": "d51e17110d5eb4e5d6e297493c44a497d82d79f7991afe5ffa864a2e7821419f",
    "Maple Bonsai.png": "91e057f0c1f3a7a332987a11e90988988b707402411e02b8947749091f50bc66",
    "Sleeping Calico.png": "e04e370321c45c95e174d4329a58c5a3fc9ddeda6407979e7c5610bc6f285b1a",
    "Maneki Neko.png": "12f608f73fb8d5dd096dc1b7ef6727bc5ef49dcea513cdbdbee4dddc809d11d9",
    "Daruma.png": "fe2b62ea2b6ebdbb440bb6ea93fe62c8b57ca6c9e71d2b58a27a8b2e5feda2ef",
}


class OrnamentAssetsTests(unittest.TestCase):
    def test_reviewed_pngs_retain_original_alpha_and_provenance_bytes(self):
        for name, digest in HASHES.items():
            data = (PACK / name).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), digest)
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            width, height, depth, color = struct.unpack(">IIBB", data[16:26])
            self.assertEqual((width, height, depth, color), (1024, 1536, 8, 6))

    def test_pack_placement_and_separate_artwork_licenses_are_present(self):
        metadata = json.loads((PACK / "ornaments.json").read_text())
        self.assertEqual(set(metadata), set(HASHES))
        for entry in metadata.values():
            self.assertEqual(entry["anchor"], "bottom")
            self.assertEqual(entry["tap"], "zoom")
            self.assertEqual(entry["night"], "off")
            self.assertGreater(entry["scale"], 0)
            self.assertLessEqual(len(entry["info"].encode("utf-8")), 4000)
            self.assertIn("https://", entry["info"])
        notices = (PACK / "ATTRIBUTION.txt").read_text()
        for required in ("Illustratedjc", "Marjorie Fitzgibbon", "Scan-the-World",
                         "CC BY-SA 4.0", "CC BY-NC-SA 4.0", "Non-commercial"):
            self.assertIn(required, notices)
        prompts = json.loads((PACK / "prompts.json").read_text())
        self.assertEqual({asset["file"] for asset in prompts["assets"]}, set(HASHES))

    def test_all_additional_busts_retain_reviewed_rgba_and_provenance(self):
        folder = ROOT / "assets/ornaments/Authors"
        self.assertEqual({p.name for p in folder.glob("*.png")}, set(AUTHOR_HASHES))
        for name, digest in AUTHOR_HASHES.items():
            with self.subTest(name=name):
                data = (folder / name).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), digest)
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                self.assertEqual(struct.unpack(">IIBB", data[16:26]), (1024, 1536, 8, 6))
                self.assertIn(b"c2pa", data)

    def test_additional_busts_have_placement_prompts_and_per_asset_licenses(self):
        folder = ROOT / "assets/ornaments/Authors"
        metadata = json.loads((folder / "ornaments.json").read_text())
        prompts = json.loads((folder / "prompts.json").read_text())
        notices = (folder / "ATTRIBUTION.txt").read_text()
        self.assertEqual(set(metadata), set(AUTHOR_HASHES))
        self.assertEqual({a["file"] for a in prompts["assets"]}, set(AUTHOR_HASHES))
        originals = {"Thomas Mann.png", "Knut Hamsun.png", "Clarice Lispector.png", "Robert Musil.png"}
        for asset in prompts["assets"]:
            name = asset["file"]
            with self.subTest(name=name):
                self.assertEqual(asset["sha256"], AUTHOR_HASHES[name])
                self.assertEqual(asset["references"] == [], name in originals)
                self.assertIn("transparent", asset["prompt"])
                entry = metadata[name]
                self.assertEqual(entry["anchor"], "bottom")
                self.assertEqual(entry["tap"], "zoom")
                self.assertEqual(entry["night"], "off")
                self.assertEqual(entry["mirror"], "off")
                self.assertTrue(.95 <= entry["scale"] <= 1.1)
                self.assertTrue(-.05 < entry["lift"] <= 0)
                self.assertLessEqual(len(entry["info"].encode("utf-8")), 4000)
                self.assertIn(asset["artwork_license"], entry["info"])
                self.assertIn("https://creativecommons.org/licenses/", entry["info"])
                self.assertIn(name.upper(), notices.upper())
        self.assertIn("Non-commercial use only", metadata["Fyodor Dostoevsky.png"]["info"])
        self.assertIn("CC BY-SA 4.0", metadata["Stanislaw Lem.png"]["info"])
        for required in ("nicolasdiolez", "Staszek Szybki Jest", "AndyScott", "Scan-the-World",
                         "No third-party sculpture or photograph was supplied", "NonCommercial-ShareAlike"):
            self.assertIn(required, notices)

    def test_japan_pngs_keep_reviewed_colour_alpha_and_generated_bytes(self):
        folder = ROOT / "assets/ornaments/Japan"
        prompts = json.loads((folder / "prompts.json").read_text())
        self.assertEqual({p.name for p in folder.glob("*.png")}, set(JAPAN_HASHES))
        self.assertEqual({a["file"] for a in prompts["assets"]}, set(JAPAN_HASHES))
        self.assertIn("built-in image_gen", prompts["tool"])
        for asset in prompts["assets"]:
            with self.subTest(name=asset["file"]):
                data = (folder / asset["file"]).read_bytes()
                digest = JAPAN_HASHES[asset["file"]]
                self.assertEqual(hashlib.sha256(data).hexdigest(), digest)
                self.assertEqual(asset["sha256"], digest)
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                self.assertEqual(struct.unpack(">IIBB", data[16:26]),
                                 (asset["width"], asset["height"], 8, 6))
                self.assertIn(b"c2pa", data)
                self.assertEqual(asset["references"], [])
                self.assertIn("transparent", asset["prompt"])
                self.assertIn("color e-ink", asset["prompt"])

    def test_japan_defaults_preserve_colour_and_put_visible_bases_at_shelf_height(self):
        folder = ROOT / "assets/ornaments/Japan"
        metadata = json.loads((folder / "ornaments.json").read_text())
        prompts = json.loads((folder / "prompts.json").read_text())
        notices = (folder / "ATTRIBUTION.txt").read_text()
        self.assertEqual(set(metadata), set(JAPAN_HASHES))
        for asset in prompts["assets"]:
            name = asset["file"]
            with self.subTest(name=name):
                entry = metadata[name]
                self.assertEqual(entry["night"], "off")
                self.assertEqual(entry["mirror"], "off")
                self.assertEqual(entry["anchor"], "bottom")
                self.assertEqual(entry["tap"], "zoom")
                self.assertTrue(.5 <= entry["scale"] <= 1)
                self.assertTrue(-.1 < entry["lift"] <= 0)
                self.assertTrue(0 <= entry["pad"] <= .05)
                bottom_margin = 1 - asset["alpha_bbox_at_24"][3] / asset["height"]
                # Native sizeFor uses 80% of stand height, then ornamentY
                # applies lift in stand-height units. Leave a tiny clear gap.
                base_gap = .8 * entry["scale"] * bottom_margin + entry["lift"]
                self.assertTrue(0 <= base_gap <= .006)
                self.assertIn("Original AI-generated", entry["info"])
                self.assertIn(asset["artwork_license"], entry["info"])
                self.assertIn("https://creativecommons.org/licenses/", entry["info"])
                self.assertIn(name, notices)

    def test_japan_preview_uses_every_production_asset_and_placement_default(self):
        metadata = json.loads((ROOT / "assets/ornaments/Japan/ornaments.json").read_text())
        preview = (ROOT / "docs/japan-ornaments-preview.html").read_text()
        for name, entry in metadata.items():
            self.assertIn('../assets/ornaments/Japan/' + quote(name), preview)
            self.assertIn(f'--scale:{entry["scale"]};--lift:{entry["lift"]}', preview)
        self.assertIn("not a KOReader emulator", preview)


if __name__ == "__main__":
    unittest.main()
