import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Authors"


class MannAssetsTests(unittest.TestCase):
    def setUp(self):
        self.art = json.loads((ROOT / "scripts/artwork/mann-seitz.json").read_text())
        self.migration = json.loads((ROOT / "assets/ornament-updates/mann-photo-v3.json").read_text())

    def test_reviewed_png_provenance_and_frozen_upgrade_hashes_agree(self):
        data = (PACK / self.art["file"]).read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), self.art["sha256"])
        self.assertEqual(self.migration["new_sha256"], self.art["sha256"])
        self.assertEqual(self.migration["old_sha256"], [
            "e584052943e66f9edc23622a48fc7f4f1c7482d306c4d8a080c74a896e6e68a7",
            "fc6d71bd1538bee9a569a9838b7a00c5374469f0cc8efad3c70674a20c286bb9",
            "04b38c71eab6150fa45643de6b09264ec442556369057f8cbd39d2a895d8d233"])
        prompt = next(a for a in json.loads((PACK / "prompts.json").read_text())["assets"]
                      if a["file"] == self.art["file"])
        self.assertEqual(prompt, self.art)
        self.assertIn("20240411_xl_0704-Thomas_Mann_B%C3%BCste_3.jpg", self.art["source_image"])
        self.assertNotIn(b"c2pa", data)
        self.assertNotIn("prompt", self.art)
        self.assertIn("No generative reconstruction", self.art["method"])
        mask = ROOT / "scripts/artwork/sculpture-masks/Thomas Mann.png"
        self.assertEqual(hashlib.sha256(mask.read_bytes()).hexdigest(), self.art["mask_sha256"])

    def test_transparent_colour_image_matches_native_base_alignment_and_preview(self):
        with Image.open(PACK / self.art["file"]) as im:
            self.assertEqual(im.mode, "RGBA")
            self.assertEqual(im.size, (1024, 1536))
            alpha = im.getchannel("A")
            self.assertEqual(list(alpha.point(lambda p: 255 if p >= 24 else 0).getbbox()),
                             self.art["alpha_bbox_at_24"])
            for point in ((0, 0), (1023, 0), (0, 1535), (1023, 1535)):
                self.assertEqual(alpha.getpixel(point), 0)
            self.assertNotEqual(im.getchannel("R").tobytes(), im.getchannel("B").tobytes())
        entry = json.loads((PACK / "ornaments.json").read_text())[self.art["file"]]
        gap = .8 * entry["scale"] * (1 - self.art["alpha_bbox_at_24"][3] / 1536) + entry["lift"]
        self.assertTrue(0 <= gap <= .006)
        self.assertEqual(entry["night"], "off")
        self.assertEqual(entry["tap"], "zoom")
        self.assertIn(f'--scale:{entry["scale"]};--lift:{entry["lift"]}',
                      (ROOT / "docs/ornaments-preview.html").read_text())

    def test_notice_separates_current_photo_basis_from_retired_image_hold(self):
        notice = (PACK / "THOMAS-MANN-SEITZ.txt").read_text()
        for value in ("Molgreen", "Gustav Seitz", "1954", "2007", "CC BY-SA 4.0",
                      "RETIRED IMAGE - RELEASE HOLD REMAINS", "no generative reconstruction",
                      "Do not push", self.art["sha256"], self.art["source_sha256"],
                      self.art["rights_basis"], self.art["mask_sha256"],
                      "including commits containing it"):
            self.assertIn(value, notice)
        self.assertIn("THOMAS-MANN-SEITZ.txt", (ROOT / "AGENTS.md").read_text())
        for path in (ROOT / "core/orbitui_author_ornaments.lua", ROOT / "scripts/check-package.lua"):
            self.assertIn("THOMAS-MANN-SEITZ.txt", path.read_text())
        notice = (PACK / "ATTRIBUTION.txt").read_text()
        self.assertIn("THOMAS MANN.PNG - MOLGREEN PHOTOGRAPHIC CUTOUT", notice)
        self.assertNotIn("ORIGINAL PORTRAIT INTERPRETATIONS", notice)

    def test_old_info_is_frozen_and_new_info_describes_the_actual_image(self):
        baseline = json.loads((ROOT / "assets/ornament-updates/author-info-v1.json").read_text())
        self.assertIn(baseline["packs"]["Authors"]["metadata"][self.art["file"]]["info"],
                      self.migration["old_info"])
        self.assertEqual(len(self.migration["old_info"]), 4)
        for text in self.migration["old_info"][:2]:
            self.assertIn("Original AI-generated", text)
        self.assertIn("Pauline Ahrens", self.migration["old_info"][2])
        self.assertIn("Molgreen", self.migration["old_info"][3])
        entry = json.loads((PACK / "ornaments.json").read_text())[self.art["file"]]
        self.assertIn(self.art["info"], entry["info"])
        self.assertNotIn("Original AI-generated", entry["info"])
        self.assertNotIn("Pauline Ahrens", entry["info"])
        self.assertNotIn("image_gen", entry["info"])
        for name, hashes in self.migration["documents"].items():
            self.assertNotIn(hashlib.sha256((PACK / name).read_bytes()).hexdigest(), hashes)

    def test_excluded_joyce_woolf_and_kafka_retain_their_reviewed_bytes(self):
        expected = {
            "Modernists/James Joyce.png": "fd0e35430db5fcb70dcbe5de222c50b448b8ffbc73e22cb5e7a2eb59fbd2e5b4",
            "Modernists/Virginia Woolf.png": "8b8a1a3d57d2df298bf7896b770d941b34682fab81ed1823f69075af46a992fb",
            "Authors/Franz Kafka.png": "1eb6d88d1c00f2b7ecb932146798e056e02bf5e2ed54b77dee702d2056a6202e",
        }
        for name, digest in expected.items():
            data = (ROOT / "assets/ornaments" / name).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), digest, name)

    @unittest.skipUnless(os.environ.get("SCULPTURE_SOURCE_CACHE"), "Set SCULPTURE_SOURCE_CACHE for source-pixel audit")
    def test_cutout_reproduces_exactly_from_original_photo_and_reviewed_mask(self):
        path = ROOT / "scripts/build-sculpture-cutouts.py"
        spec = importlib.util.spec_from_file_location("mann_cutout", path)
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        config = json.loads((ROOT / "scripts/artwork/mann-photo-cutout.json").read_text())["assets"][0]
        source = Path(os.environ["SCULPTURE_SOURCE_CACHE"]) / self.art["source_file"]
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), self.art["source_sha256"])
        with Image.open(source) as photo, Image.open(PACK / self.art["file"]) as bundled:
            rendered = builder.cutout(photo, config, ROOT / "scripts/artwork/sculpture-masks" / self.art["file"], False)
            self.assertEqual(rendered.tobytes(), bundled.tobytes())

    def test_notice_builder_preserves_the_frozen_migration_and_provenance(self):
        paths = [PACK / "THOMAS-MANN-SEITZ.txt", ROOT / "scripts/artwork/mann-seitz.json",
                 ROOT / "assets/ornament-updates/mann-photo-v2.json",
                 ROOT / "assets/ornament-updates/mann-photo-v3.json"]
        before = [p.read_bytes() for p in paths]
        subprocess.run(["python3", "scripts/build-mann-photo.py"], cwd=ROOT, check=True)
        self.assertEqual(before, [p.read_bytes() for p in paths])


if __name__ == "__main__":
    unittest.main()
