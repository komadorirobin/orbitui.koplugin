import importlib.util
import json
from pathlib import Path
import unittest
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_author_info", ROOT / "scripts/build-author-info.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class AuthorInfoAssetsTests(unittest.TestCase):
    def setUp(self):
        self.bios = json.loads(builder.CONTENT.read_text(encoding="utf-8"))
        self.baseline = json.loads(builder.BASELINE.read_text(encoding="utf-8"))

    def test_all_eleven_bios_have_life_works_and_explicit_editorial_sources(self):
        expected = {name for pack in self.baseline["packs"].values() for name in pack["metadata"]}
        self.assertEqual(set(self.bios), expected)
        self.assertEqual(len(expected), 11)
        for name, bio in self.bios.items():
            with self.subTest(name=name):
                self.assertTrue(bio["name"])
                self.assertRegex(bio["years"], r"^\d{4}-\d{4}$")
                self.assertEqual(len(bio["paragraphs"]), 2)
                self.assertGreater(len(" ".join(bio["paragraphs"]).split()), 100)
                self.assertGreaterEqual(len(bio["works"].split(";")), 4)
                self.assertGreaterEqual(len(bio["sources"]), 2)
                for source in bio["sources"]:
                    self.assertTrue(source["title"])
                    url = urlparse(source["url"])
                    self.assertEqual(url.scheme, "https")
                    self.assertTrue(url.netloc)

    def test_runtime_cards_are_reproducible_byte_limited_and_keep_original_credits_verbatim(self):
        self.assertEqual(self.baseline["source_commit"], builder.SOURCE_COMMIT)
        for pack, old in self.baseline["packs"].items():
            current = json.loads((ROOT / "assets/ornaments" / pack / "ornaments.json").read_text())
            self.assertEqual(set(current), set(old["metadata"]))
            for name, before in old["metadata"].items():
                with self.subTest(pack=pack, name=name):
                    after = current[name]
                    self.assertEqual(after["info"], builder.info_text(self.bios[name], before["info"]))
                    self.assertLessEqual(len(after["info"].encode("utf-8")), 4000)
                    self.assertEqual(after["info"].split(builder.ART_HEADING + "\n", 1)[1], before["info"])
                    self.assertIn(builder.CREDIT, after["info"])
                    self.assertEqual({k: v for k, v in after.items() if k != "info"},
                                     {k: v for k, v in before.items() if k != "info"})
                    self.assertEqual(after["tap"], "zoom")

    def test_default_readmes_describe_biographies_separately_from_artwork(self):
        for pack, old in self.baseline["packs"].items():
            text = (ROOT / "assets/ornaments" / pack / "README.txt").read_text()
            self.assertNotEqual(text, old["readme"])
            for required in ("life", "major works", "Swedish", "source links", "offline",
                             "Custom captions", "Image bytes", "ATTRIBUTION.txt"):
                self.assertIn(required, text)


if __name__ == "__main__":
    unittest.main()
