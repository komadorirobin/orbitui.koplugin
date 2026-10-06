import hashlib
import importlib.util
import json
import os
from pathlib import Path
import unittest
from urllib.parse import quote

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "scripts/artwork"
PACK = ROOT / "assets/ornaments/Authors II"


def load_script(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class AuthorAdditionAssetsTests(unittest.TestCase):
    def setUp(self):
        self.assets = json.loads((ART / "author-additions.json").read_text())
        self.specs = json.loads((ART / "sculpture-additions.json").read_text())["assets"]
        self.bios = json.loads((ART / "author-addition-biographies.json").read_text())
        self.metadata = json.loads((PACK / "ornaments.json").read_text())

    def test_two_photographic_assets_provenance_masks_and_runtime_inventory_agree(self):
        names = {"Ernest Hemingway.png", "Italo Svevo.png"}
        self.assertEqual({a["file"] for a in self.assets}, names)
        self.assertEqual({a["file"] for a in self.specs}, names)
        self.assertEqual({p.name for p in PACK.glob("*.png")}, names)
        self.assertEqual(set(self.bios), names)
        self.assertEqual(set(self.metadata), names)
        self.assertEqual(json.loads((PACK / "prompts.json").read_text())["assets"], self.assets)
        for asset in self.assets:
            with self.subTest(name=asset["file"]):
                self.assertEqual(digest(PACK / asset["file"]), asset["sha256"])
                self.assertEqual(digest(ART / "sculpture-masks" / asset["file"]), asset["mask_sha256"])
                self.assertIn("No generative reconstruction", asset["method"])
                self.assertNotIn("prompt", asset)
                self.assertNotIn(b"c2pa", (PACK / asset["file"]).read_bytes())

    def test_colour_alpha_placement_and_native_zoom_info(self):
        formatter = load_script("build-author-info")
        preview = (ROOT / "docs/ornaments-preview.html").read_text()
        for asset in self.assets:
            name = asset["file"]
            with self.subTest(name=name), Image.open(PACK / name) as img:
                self.assertEqual(img.mode, "RGBA")
                self.assertEqual(img.size, (asset["width"], asset["height"]))
                self.assertNotEqual(img.getchannel("R").tobytes(), img.getchannel("B").tobytes())
                alpha = img.getchannel("A")
                self.assertEqual(alpha.getextrema(), (0, 255))
                self.assertEqual(list(alpha.point(lambda v: 255 if v >= 24 else 0).getbbox()), asset["alpha_bbox_at_24"])
                entry = self.metadata[name]
                self.assertEqual(entry["tap"], "zoom")
                self.assertEqual(entry["night"], "off")
                self.assertEqual(entry["info"], formatter.info_text(self.bios[name], asset["info"]))
                self.assertLessEqual(len(entry["info"].encode()), 4000)
                self.assertGreater(len(" ".join(self.bios[name]["paragraphs"]).split()), 100)
                self.assertGreaterEqual(len(self.bios[name]["sources"]), 2)
                gap = .8 * entry["scale"] * (1-asset["alpha_bbox_at_24"][3]/asset["height"]) + entry["lift"]
                self.assertTrue(0 <= gap <= .006)
                self.assertIn('../assets/ornaments/Authors%20II/' + quote(name), preview)

    def test_notices_are_hash_scoped_and_distinguish_photo_from_sculpture_rights(self):
        notice = (PACK / "ATTRIBUTION.txt").read_text()
        self.assertIn("not to custom replacements", notice)
        for asset in self.assets:
            for key in ("file", "reference_credit", "rights_basis", "sha256", "source_sha256", "license_url"):
                self.assertIn(asset[key], notice)
        self.assertIn("Dazai is not bundled", (PACK / "README.txt").read_text())
        self.assertIn("No suitable licensed photo", (ROOT / "docs/AUTHOR_SCULPTURE_RESEARCH.md").read_text())

    def test_offline_card_builder_is_reproducible_and_does_not_touch_old_packs(self):
        paths = [p for folder in ("Modernists", "Authors", "Authors II")
                 for p in (ROOT / "assets/ornaments" / folder).iterdir() if p.is_file()]
        paths += list((ROOT / "assets/ornament-updates").glob("*.json"))
        before = {p: digest(p) for p in paths}
        load_script("build-author-additions").build()
        self.assertEqual({p: digest(p) for p in paths}, before)

    @unittest.skipUnless(os.environ.get("SCULPTURE_SOURCE_CACHE"), "Set SCULPTURE_SOURCE_CACHE for source-pixel audit")
    def test_source_pixels_reproduce_both_images_including_hemingway_crop(self):
        builder = load_script("build-sculpture-cutouts")
        for asset in self.assets:
            with self.subTest(name=asset["file"]):
                source = Path(os.environ["SCULPTURE_SOURCE_CACHE"]) / asset["source_file"]
                self.assertEqual(digest(source), asset["source_sha256"])
                spec = next(s for s in self.specs if s["file"] == asset["file"])
                with Image.open(source) as original, Image.open(PACK / asset["file"]) as bundled:
                    rendered = builder.cutout(original, spec, ART / "sculpture-masks" / asset["file"], False)
                    self.assertEqual(rendered.tobytes(), bundled.tobytes())


if __name__ == "__main__":
    unittest.main()
