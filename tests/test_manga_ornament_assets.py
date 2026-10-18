import hashlib
import json
from pathlib import Path
import struct
import unittest
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[1]


class MangaChecks:
    def test_original_rgba_bytes_and_generation_provenance(self):
        pack = ROOT / "assets/ornaments" / self.pack_name
        prompts = json.loads((pack / "prompts.json").read_text())
        self.assertIn("built-in image_gen", prompts["tool"])
        self.assertEqual({a["file"] for a in prompts["assets"]}, set(self.hashes))
        self.assertEqual({p.name for p in pack.glob("*.png")}, set(self.hashes))
        for asset in prompts["assets"]:
            with self.subTest(name=asset["file"]):
                data = (pack / asset["file"]).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), self.hashes[asset["file"]])
                self.assertEqual(asset["sha256"], self.hashes[asset["file"]])
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                self.assertEqual(struct.unpack(">IIBB", data[16:26]),
                                 (asset["width"], asset["height"], 8, 6))
                self.assertLess(asset["width"] * asset["height"], 4_000_000)
                self.assertIn(b"c2pa", data)
                self.assertEqual(asset["references"], [])
                self.assertIn("transparent", asset["prompt"].lower())

    def test_native_placement_zoom_and_colour_defaults(self):
        pack = ROOT / "assets/ornaments" / self.pack_name
        metadata = json.loads((pack / "ornaments.json").read_text())
        prompts = json.loads((pack / "prompts.json").read_text())
        self.assertEqual(set(metadata), set(self.hashes))
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
        pack = ROOT / "assets/ornaments" / self.pack_name
        notes = (pack / "ATTRIBUTION.txt").read_text()
        metadata = json.loads((pack / "ornaments.json").read_text())
        prompts = json.loads((pack / "prompts.json").read_text())
        for asset in prompts["assets"]:
            name = asset["file"]
            with self.subTest(name=name):
                self.assertIn(name, notes)
                if asset["artwork_license"].startswith("Unofficial"):
                    self.assertIn("unofficial fan art", metadata[name]["info"])
                    self.assertNotIn("CC BY", metadata[name]["info"])
                    self.assertIn("no blanket license", metadata[name]["info"])
                else:
                    self.assertIn("CC BY 4.0", metadata[name]["info"])

    def test_preview_and_runtime_use_every_production_piece(self):
        pack = ROOT / "assets/ornaments" / self.pack_name
        html = (ROOT / "docs/manga-ornaments-preview.html").read_text()
        runtime = (ROOT / "core/orbitui_manga_ornaments.lua").read_text()
        metadata = json.loads((pack / "ornaments.json").read_text())
        for name, entry in metadata.items():
            with self.subTest(name=name):
                self.assertIn("../assets/ornaments/" + quote(self.pack_name + "/" + name), html)
                self.assertIn('data-scale="' + str(entry["scale"]) + '"', html)
                self.assertIn("--lift:" + str(entry["lift"]), html)
                self.assertIn('["' + self.pack_name + "/" + name + '"]', runtime)


class MangaOrnamentAssetsTests(MangaChecks, unittest.TestCase):
    pack_name = "Manga"
    hashes = {
        "Kaneda Motorcycle.png": "84228bbb148dcbfa254ee1fbb5a4cb55ea2d9372cdf5a468b6ee40b16a94b169",
        "Walking Mushroom.png": "2538c61741cd32657e180d91c79e19af354c9a5a96a9df63fdca2ee93ff34b5a",
        "Apothecary Mortar.png": "7390228f5552cdfebb8c48bc24b66bce072e20096a09e3ff3dd3d17bb0ea17e1"
    }


class MangaIIOrnamentAssetsTests(MangaChecks, unittest.TestCase):
    pack_name = "Manga II"
    hashes = {
        "Nyanko Sensei.png": "f031b3f5d484a849e2ed0af96128a7bceeabc46722d1b4a2ebc8820eaf113f3f",
        "Brushbuddy.png": "e50919295fc03edc5ce8fceac9d7ab89f0d5700f4b322026e11a40a1f34c7782",
        "Ohmu.png": "6d0239dd7b8c46b84791265c6c0d46c259cebe0aff27a9b014c9103c4dd2494e",
        "Mimic Chest.png": "29fb1c53c90f5c97eb693b791189c2d582fce4668fd2eb59759eaadc5a93de65",
        "Pochita.png": "d9a96fec067bbae190024559ed1155f8584c9a786b503a84c13bf6289b160776",
        "Turbo Granny.png": "4ae7c69392606ff03c75eab635449eab0e63a2f88f291c320f7bbd26be12e400",
        "Transponder Snail.png": "0211f561223e2fe2240bbdd4f8b8f08cc5f297a7e9625c3a043acd12f474b918",
        "Kettenkrad.png": "09edaa3d25fa88280b3adf0b3aadaa3efe1a4bb5bfff7b0af89e239c4693325d",
        "Camp Tent.png": "bf922620eb14bee3968b4834aa1de38c9ce358fc64401b0c9ff1d55cdf177d4f",
        "Armillary Sphere.png": "ac4c6365beb07837ff6ebb0ad170e346907edf3d4681d6eb5c26865b12eac016",
        "Cafe Alpha.png": "b740cdc329d3d92d4011b276ef378f4a5dcb80f756d0f3cc609268cf1e91e2c4"
    }

    def test_all_context_captions_link_to_their_research(self):
        pack = ROOT / "assets/ornaments" / self.pack_name
        metadata = json.loads((pack / "ornaments.json").read_text())
        prompts = json.loads((pack / "prompts.json").read_text())
        self.assertEqual(len(prompts["assets"]), 11)
        for asset in prompts["assets"]:
            self.assertTrue(asset["research_sources"])
            for source in asset["research_sources"]:
                self.assertTrue(source.startswith("https://"))
                self.assertIn(source, metadata[asset["file"]]["info"])
        for name in ("Camp Tent.png", "Armillary Sphere.png", "Cafe Alpha.png"):
            self.assertIn("thematic", metadata[name]["info"].lower())


if __name__ == "__main__":
    unittest.main()
