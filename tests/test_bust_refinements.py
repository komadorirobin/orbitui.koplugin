import hashlib
import json
from pathlib import Path
import subprocess
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BEFORE = "v0.1.0-alpha.22"


def published(path):
    return subprocess.check_output(["git", "show", f"{BEFORE}:{path}"], cwd=ROOT)


def load(path):
    return json.loads((ROOT / path).read_text())


class BustRefinementTests(unittest.TestCase):
    def test_only_mann_and_hemingway_artwork_changes(self):
        changed = {"Authors/Thomas Mann.png", "Authors II/Ernest Hemingway.png"}
        for pack in ("Modernists", "Authors", "Authors II"):
            for path in (ROOT / "assets/ornaments" / pack).glob("*.png"):
                relative = path.relative_to(ROOT).as_posix()
                self.assertEqual(path.read_bytes() != published(relative),
                                 f"{pack}/{path.name}" in changed, relative)

    def test_published_migration_baselines_stay_frozen(self):
        directory = "assets/ornament-updates"
        names = subprocess.check_output(["git", "ls-tree", "--name-only", f"{BEFORE}:{directory}"],
                                        cwd=ROOT, text=True).splitlines()
        for name in names:
            path = f"{directory}/{name}"
            self.assertEqual((ROOT / path).read_bytes(), published(path), path)

    def test_new_migrations_recognize_exact_alpha22_defaults_and_keep_biographies(self):
        for pack, name, baseline in (
            ("Authors", "Thomas Mann.png", "mann-photo-v4"),
            ("Authors II", "Ernest Hemingway.png", "hemingway-photo-v1"),
        ):
            prefix = f"assets/ornaments/{pack}/"
            migration = load(f"assets/ornament-updates/{baseline}.json")
            old = json.loads(published(prefix + "ornaments.json"))[name]
            new = load(prefix + "ornaments.json")[name]
            self.assertIn(hashlib.sha256(published(prefix + name)).hexdigest(), migration["old_sha256"])
            self.assertEqual(hashlib.sha256((ROOT / prefix / name).read_bytes()).hexdigest(), migration["new_sha256"])
            self.assertIn(old["info"], migration["old_info"])
            self.assertIn({key: old[key] for key in ("scale", "anchor", "lift")}, migration["old_placements"])
            heading = "Om bysten / bildkrediter:"
            self.assertEqual(new["info"].split(heading)[0], old["info"].split(heading)[0])
            for key in ("night", "tap", "mirror", "pad"):
                self.assertEqual(new[key], old[key])
            for document, hashes in migration["documents"].items():
                self.assertIn(hashlib.sha256(published(prefix + document)).hexdigest(), hashes)

    def test_hemingway_has_larger_visible_height_without_transparent_overhang(self):
        art = next(a for a in load("scripts/artwork/author-additions.json") if a["file"] == "Ernest Hemingway.png")
        old = next(a for a in json.loads(published("scripts/artwork/author-additions.json")) if a["file"] == art["file"])
        self.assertEqual((art["width"], art["height"]), (1024, 896))
        self.assertEqual(art["placement"]["scale"], 1)
        visible = (art["alpha_bbox_at_24"][3] - art["alpha_bbox_at_24"][1]) / art["height"]
        before = (old["alpha_bbox_at_24"][3] - old["alpha_bbox_at_24"][1]) / old["height"]
        self.assertGreater(visible / before, 1.6)
        # The entire image, not only its opaque bust, fits below the row top.
        self.assertLessEqual(.8 * art["placement"]["scale"], 1)
        with Image.open(ROOT / "assets/ornaments/Authors II" / art["file"]) as im:
            alpha = im.getchannel("A")
            left, _, right, bottom = art["alpha_bbox_at_24"]
            bases = [max(y for y in range(im.height) if alpha.getpixel((x, y)) >= 24)
                     for x in range(left + 12, right - 12, 12)]
            # Feathered side edges may differ by one pixel at shelf scale.
            self.assertLessEqual(max(bases) - min(bases), 4)
            self.assertLessEqual(bottom - 1 - max(bases), 1)

    def test_mann_has_frontal_mounting_block_and_plinth_from_original_photo(self):
        art = load("scripts/artwork/mann-seitz.json")
        old = json.loads(published("scripts/artwork/mann-seitz.json"))
        self.assertNotEqual(art["source_sha256"], old["source_sha256"])
        self.assertIn("Pauline_Ahrens_2022.jpg", art["source_image"])
        self.assertIn("thin bronze plinth", art["framing"])
        self.assertEqual(art["placement"]["scale"], 1)
        self.assertLess(art["alpha_bbox_at_24"][1] / art["height"], .09)


if __name__ == "__main__":
    unittest.main()
