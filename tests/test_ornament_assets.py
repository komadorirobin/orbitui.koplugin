import hashlib
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Modernists"
HASHES = {
    "James Joyce.png": "fd0e35430db5fcb70dcbe5de222c50b448b8ffbc73e22cb5e7a2eb59fbd2e5b4",
    "Virginia Woolf.png": "8b8a1a3d57d2df298bf7896b770d941b34682fab81ed1823f69075af46a992fb",
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
            self.assertLess(len(entry["info"]), 4000)
            self.assertIn("https://", entry["info"])
        notices = (PACK / "ATTRIBUTION.txt").read_text()
        for required in ("Illustratedjc", "Marjorie Fitzgibbon", "Scan-the-World",
                         "CC BY-SA 4.0", "CC BY-NC-SA 4.0", "Non-commercial"):
            self.assertIn(required, notices)
        prompts = json.loads((PACK / "prompts.json").read_text())
        self.assertEqual({asset["file"] for asset in prompts["assets"]}, set(HASHES))


if __name__ == "__main__":
    unittest.main()
