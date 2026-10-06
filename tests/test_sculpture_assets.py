import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import unittest
from urllib.parse import quote

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Authors"
ART = ROOT / "scripts/artwork"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SculptureAssetsTests(unittest.TestCase):
    def setUp(self):
        self.assets = json.loads((ART / "author-sculptures.json").read_text())
        self.specs = json.loads((ART / "sculpture-cutouts.json").read_text())["assets"]
        self.migration = json.loads((ROOT / "assets/ornament-updates/author-sculptures-v1.json").read_text())

    def test_six_reviewed_photos_masks_provenance_and_frozen_old_images_agree(self):
        self.assertEqual(len(self.assets), 6)
        self.assertEqual({a["file"] for a in self.assets}, {s["file"] for s in self.specs})
        bundled = json.loads((PACK / "prompts.json").read_text())["assets"]
        for asset in self.assets:
            name = asset["file"]
            with self.subTest(name=name):
                old = next(a for a in self.migration["assets"] if a["file"] == name)
                self.assertEqual(digest(PACK / name), asset["sha256"])
                self.assertEqual(old["new_sha256"], asset["sha256"])
                before = subprocess.check_output(["git", "show", "v0.1.0-alpha.21:assets/ornaments/Authors/" + name], cwd=ROOT)
                self.assertEqual(hashlib.sha256(before).hexdigest(), old["old_sha256"])
                self.assertNotEqual(old["old_sha256"], old["new_sha256"])
                self.assertEqual(digest(ART / "sculpture-masks" / name), asset["mask_sha256"])
                self.assertEqual(next(a for a in bundled if a["file"] == name), asset)
                self.assertIn("No generative reconstruction", asset["method"])
                self.assertNotIn("prompt", asset)
                self.assertNotIn(b"c2pa", (PACK / name).read_bytes())

    def test_rgba_base_alignment_biographies_zoom_and_preview(self):
        metadata = json.loads((PACK / "ornaments.json").read_text())
        preview = (ROOT / "docs/ornaments-preview.html").read_text()
        for asset in self.assets:
            name = asset["file"]
            with self.subTest(name=name), Image.open(PACK / name) as img:
                self.assertEqual(img.mode, "RGBA")
                self.assertEqual(img.size, (1024, 1536))
                alpha = img.getchannel("A")
                self.assertEqual(alpha.getextrema(), (0, 255))
                self.assertEqual(list(alpha.point(lambda v: 255 if v >= 24 else 0).getbbox()), asset["alpha_bbox_at_24"])
                entry = metadata[name]
                self.assertEqual(entry["tap"], "zoom")
                self.assertEqual(entry["night"], "off")
                self.assertIn("Centrala verk:", entry["info"])
                self.assertIn(asset["info"], entry["info"])
                self.assertLessEqual(len(entry["info"].encode()), 4000)
                gap = .8 * entry["scale"] * (1-asset["alpha_bbox_at_24"][3]/1536) + entry["lift"]
                self.assertTrue(0 <= gap <= .006)
                self.assertIn('../assets/ornaments/Authors/' + quote(name), preview)
                self.assertIn(f'--scale:{entry["scale"]};--lift:{entry["lift"]}', preview)
                if name == "Knut Hamsun.png":
                    self.assertEqual(img.getchannel("R").tobytes(), img.getchannel("G").tobytes())
                else:
                    self.assertNotEqual(img.getchannel("R").tobytes(), img.getchannel("B").tobytes())

    def test_dedicated_notice_has_exact_hash_scoped_credit_and_separate_rights_basis(self):
        text = (PACK / "AUTHOR-SCULPTURES.txt").read_text()
        self.assertIn("not to custom replacements", text)
        for asset in self.assets:
            for value in (asset["file"], asset["sha256"], asset["source_sha256"],
                          asset["reference_credit"], asset["license_url"], asset["rights_basis"]):
                self.assertIn(value, text)
        for path in ("core/orbitui_author_ornaments.lua", "scripts/check-package.lua"):
            self.assertIn("AUTHOR-SCULPTURES.txt", (ROOT / path).read_text())

    @unittest.skipUnless(os.environ.get("SCULPTURE_SOURCE_CACHE"), "Set SCULPTURE_SOURCE_CACHE for source-pixel audit")
    def test_every_runtime_image_reproduces_from_original_photo_and_reviewed_mask(self):
        spec = importlib.util.spec_from_file_location("cutouts", ROOT / "scripts/build-sculpture-cutouts.py")
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        source_dir = Path(os.environ["SCULPTURE_SOURCE_CACHE"])
        for asset in self.assets:
            with self.subTest(name=asset["file"]):
                source = source_dir / asset["source_file"]
                self.assertEqual(digest(source), asset["source_sha256"])
                config = next(s for s in self.specs if s["file"] == asset["file"])
                with Image.open(source) as photo, Image.open(PACK / asset["file"]) as bundled:
                    rendered = builder.cutout(photo, config, ART / "sculpture-masks" / asset["file"], False)
                    self.assertEqual(rendered.tobytes(), bundled.tobytes())


if __name__ == "__main__":
    unittest.main()
