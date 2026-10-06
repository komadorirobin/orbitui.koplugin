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
            retired = builder.RETIRED.get(pack, set())
            self.assertEqual(set(current), set(old["metadata"]) - retired)
            for name, before in old["metadata"].items():
                if name in retired:
                    continue
                with self.subTest(pack=pack, name=name):
                    after = current[name]
                    credit = builder.artwork_credit(name, before["info"])
                    self.assertEqual(after["info"], builder.info_text(self.bios[name], credit))
                    self.assertLessEqual(len(after["info"].encode("utf-8")), 4000)
                    self.assertEqual(after["info"].split(builder.ART_HEADING + "\n", 1)[1], credit)
                    self.assertIn(builder.CREDIT, after["info"])
                    expected = {k: v for k, v in before.items() if k != "info"}
                    if name == "Franz Kafka.png":
                        expected.update(json.loads(builder.KAFKA.read_text())["placement"])
                    elif name == "Thomas Mann.png":
                        expected.update(json.loads(builder.MANN.read_text())["placement"])
                    for asset in json.loads(builder.SCULPTURES.read_text()):
                        if name == asset["file"]:
                            expected.update(asset["placement"])
                    self.assertEqual({k: v for k, v in after.items() if k != "info"}, expected)
                    self.assertEqual(after["tap"], "zoom")

    def test_default_readmes_describe_biographies_separately_from_artwork(self):
        for pack, old in self.baseline["packs"].items():
            text = (ROOT / "assets/ornaments" / pack / "README.txt").read_text()
            self.assertNotEqual(text, old["readme"])
            for required in ("life", "major works", "Swedish", "source links", "offline",
                             "Custom captions", "Image bytes", "ATTRIBUTION.txt"):
                self.assertIn(required, text)

    def test_retired_lispector_keeps_source_biography_but_no_runtime_artwork_or_card(self):
        name = "Clarice Lispector.png"
        self.assertEqual(builder.RETIRED, {"Authors": {name}})
        self.assertIn(name, self.bios)
        self.assertIn(name, self.baseline["packs"]["Authors"]["metadata"])
        folder = ROOT / "assets/ornaments/Authors"
        self.assertFalse((folder / name).exists())
        self.assertNotIn(name, json.loads((folder / "ornaments.json").read_text()))
        prompts = json.loads((folder / "prompts.json").read_text())
        self.assertNotIn(name, {a["file"] for a in prompts["assets"]})
        retirement = (ROOT / "core/orbitui_lispector_retirement.lua").read_text()
        self.assertIn("bee7a3d24770d1931d4144b3e5ad1c8b71beaac0d10b5acbf9f43d317524343a", retirement)


if __name__ == "__main__":
    unittest.main()
