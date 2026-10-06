import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Authors"


class KafkaAssetsTests(unittest.TestCase):
    def setUp(self):
        self.art = json.loads((ROOT / "scripts/artwork/kafka-kielce.json").read_text())
        self.migration = json.loads((ROOT / "assets/ornament-updates/kafka-kielce-v1.json").read_text())

    def test_output_hash_and_provenance_match_the_reviewed_photo_adaptation(self):
        art = self.art
        data = (PACK / art["file"]).read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), art["sha256"])
        self.assertEqual(self.migration["new_sha256"], art["sha256"])
        self.assertEqual(self.migration["old_sha256"],
                         "cf92760b445de7cca2ae7aaf44fabf745f6f9f25268ac8025397fd556a7969c9")
        prompt = next(a for a in json.loads((PACK / "prompts.json").read_text())["assets"]
                      if a["file"] == art["file"])
        self.assertEqual(prompt, art)
        self.assertIn("background-extraction", art["prompt"])
        self.assertIn("bronze", art["prompt"])
        self.assertIn("Popiersie_Franz_Kafka_ssj_20060914.jpg", art["source_image"])
        self.assertIn(b"c2pa", data)

    def test_alpha_and_native_base_alignment_preserve_colour_without_background(self):
        with Image.open(PACK / self.art["file"]) as im:
            self.assertEqual(im.mode, "RGBA")
            self.assertEqual(im.size, (self.art["width"], self.art["height"]))
            a = im.getchannel("A")
            self.assertEqual(list(a.point(lambda p: 255 if p >= 24 else 0).getbbox()),
                             self.art["alpha_bbox_at_24"])
            for p in [(0, 0), (1023, 0), (0, 1535), (1023, 1535), (100, 750)]:
                self.assertEqual(a.getpixel(p), 0)
            r, g, b, alpha = im.getpixel((512, 900))
            self.assertGreater(alpha, 240)
            self.assertGreater(max(r, g, b) - min(r, g, b), 10)
        entry = json.loads((PACK / "ornaments.json").read_text())[self.art["file"]]
        gap = .8 * entry["scale"] * (1 - self.art["alpha_bbox_at_24"][3] / self.art["height"]) + entry["lift"]
        self.assertTrue(0 <= gap <= .006)
        self.assertEqual(entry["night"], "off")
        self.assertEqual(entry["tap"], "zoom")
        preview = (ROOT / "docs/ornaments-preview.html").read_text()
        self.assertIn(f'--scale:{entry["scale"]};--lift:{entry["lift"]}', preview)

    def test_license_and_sculpture_rights_are_distinct_with_change_notice(self):
        notice = (PACK / "KAFKA-KIELCE.txt").read_text()
        for value in ("Staszek Szybki Jest", "Anna Wierzchowska-Grabiwoda", "2005",
                      "CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/",
                      "not ownership of the", "freedom of panorama", "not a pixel-identical",
                      "supersedes older Kafka-only credits", self.art["sha256"]):
            self.assertIn(value, notice)
        attribution = (PACK / "ATTRIBUTION.txt").read_text()
        self.assertNotIn("Franz Kafka.png", attribution.split("ORIGINAL PORTRAIT INTERPRETATIONS")[1])
        self.assertIn("KAFKA-KIELCE.txt", attribution)

    def test_frozen_old_captions_are_not_rewritten_to_claim_kielce_credits(self):
        baseline = json.loads((ROOT / "assets/ornament-updates/author-info-v1.json").read_text())
        old = baseline["packs"]["Authors"]["metadata"][self.art["file"]]
        self.assertIn(old["info"], self.migration["old_info"])
        self.assertEqual(len(self.migration["old_info"]), 2)
        for info in self.migration["old_info"]:
            self.assertIn("Original AI-generated light-plaster portrait", info)
        current = json.loads((PACK / "ornaments.json").read_text())[self.art["file"]]
        self.assertNotIn("Original AI-generated light-plaster", current["info"])
        self.assertIn(self.art["info"], current["info"])
        for name, values in self.migration["documents"].items():
            self.assertNotIn(hashlib.sha256((PACK / name).read_bytes()).hexdigest(), values)


if __name__ == "__main__":
    unittest.main()
