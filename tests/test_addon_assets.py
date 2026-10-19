import importlib.util
import json
import re
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("addons_builder", ROOT / "scripts/build-ornament-addons.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class AddonAssets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.output = Path(cls.temp.name)
        cls.catalog = builder.build(cls.output, 1)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_single_manga_pack_keeps_all_legacy_paths(self):
        packs = self.catalog["packs"]
        self.assertEqual([p["name"] for p in packs if p["id"].startswith("manga")], ["Manga"])
        with zipfile.ZipFile(self.output / "manga-1.zip") as z:
            for name in ("Manga/Kaneda Motorcycle.png", "Manga II/Pochita.png", "Manga III/Quiet Bungalow.png"):
                self.assertIn(name, z.namelist())

    def test_new_releases_use_separate_repo_but_unchanged_old_packs_keep_working(self):
        prefix = "https://github.com/komadorirobin/orbitui-addons/releases/download/"
        for pack in self.catalog["packs"]:
            self.assertTrue(pack["url"].startswith(prefix))
            self.assertTrue(pack["preview"]["url"].startswith(prefix))
        legacy = json.loads(json.dumps(self.catalog))
        for pack in legacy["packs"]:
            pack["url"] = pack["url"].replace("orbitui-addons", "orbitui.koplugin")
        next_catalog = builder.build(self.output / "legacy", 2, legacy)
        for old, new in zip(legacy["packs"], next_catalog["packs"]):
            self.assertEqual(old["url"], new["url"])
            self.assertEqual(old["sha256"], new["sha256"])
            self.assertTrue(new["preview"]["url"].startswith(prefix))

    def test_every_file_is_verified_and_credits_travel_with_packs(self):
        for p in self.catalog["packs"]:
            archive = self.output / p["url"].split("/")[-1]
            self.assertEqual(builder.digest(archive.read_bytes()), p["sha256"])
            self.assertEqual(archive.stat().st_size, p["size"])
            with zipfile.ZipFile(archive) as z:
                manifest = json.loads(z.read("manifest.json"))
                self.assertEqual(len(z.namelist()), len(manifest["files"]) + 1)
                self.assertTrue(any("ATTRIBUTION" in f["path"] for f in manifest["files"]))
                for f in manifest["files"]:
                    data = z.read(f["path"])
                    self.assertEqual(builder.digest(data), f["sha256"])
                    self.assertNotEqual(f["sha256"], builder.HELD)
                    self.assertIn(Path(f["path"]).suffix.lower(), builder.EXTS)
                    if f["path"].endswith("ornaments.json"):
                        self.assertEqual(json.loads(data), manifest["defaults"][f["path"]])

    def test_immutable_versions_are_deterministic(self):
        second = builder.build(self.output / "second", 2, self.catalog)
        for first, new in zip(self.catalog["packs"], second["packs"]):
            self.assertEqual(first["sha256"], new["sha256"])
            self.assertEqual(first["url"], new["url"])
        wrong = json.loads(json.dumps(self.catalog))
        wrong["packs"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(AssertionError, "version bump"):
            builder.build(self.output / "bad", 3, wrong)

    def test_all_information_cards_are_bilingual_with_unchanged_sources(self):
        translations = json.loads((ROOT / "addons/ornament-translations.json").read_text())
        seen = set()
        for pack in self.catalog["packs"]:
            with zipfile.ZipFile(self.output / pack["url"].split("/")[-1]) as z:
                for folder in pack["folders"]:
                    path = folder + "/ornaments.json"
                    original = json.loads((ROOT / "assets/ornaments" / path).read_text())
                    for name, entry in json.loads(z.read(path)).items():
                        key = folder + "/" + name
                        seen.add(key)
                        self.assertEqual(entry["info"], original[name]["info"])
                        self.assertEqual(entry["info_source"], entry["info"])
                        urls = set(re.findall(r"https?://\S+", entry["info"]))
                        for language in ("en", "sv"):
                            text = entry["info_" + language]
                            self.assertEqual(text, translations[key][language])
                            self.assertGreater(len(text), 0)
                            self.assertLessEqual(len(text.encode()), 4000)
                            self.assertEqual(set(re.findall(r"https?://\S+", text)), urls)
                        for swedish in ("Centrala verk:", "Källor:", "Mått (museets exemplar):",
                                        "Om bysten / bildkrediter:", "AI-assisterad svensk sammanfattning"):
                            self.assertNotIn(swedish, entry["info_en"])
        self.assertEqual(seen, set(translations))

    def test_changed_source_or_incomplete_translation_blocks_release(self):
        source = {"A.png": {"info": "original"}}
        text = {"Manga/A.png": {"source_sha256": builder.digest(b"original"), "en": "original", "sv": "svenska"}}
        self.assertEqual(builder.localize(source, "Manga", text)["A.png"]["info_sv"], "svenska")
        with self.assertRaisesRegex(AssertionError, "stale translations"):
            builder.localize({"A.png": {"info": "changed"}}, "Manga", text)
        text["Manga/A.png"]["en"] = "not the original"
        with self.assertRaisesRegex(AssertionError, "Keep the original"):
            builder.localize(source, "Manga", text)
        text["Manga/A.png"]["en"] = "original"
        text["Manga/A.png"]["sv"] = "å" * 2001
        with self.assertRaisesRegex(AssertionError, "Invalid caption"):
            builder.localize(source, "Manga", text)
        text["Manga/A.png"]["sv"] = "svenska https://example.invalid/changed-source"
        with self.assertRaisesRegex(AssertionError, "Changed source/licence links"):
            builder.localize(source, "Manga", text)

    def test_runtime_has_only_catalog_and_frozen_migration_metadata(self):
        baseline = json.loads((ROOT / "assets/addons/legacy-v1.json").read_text())
        self.assertEqual(baseline["schema"], 1)
        runtime = json.loads((ROOT / "assets/addons/catalog.json").read_text())
        self.assertTrue(all("url" not in p for p in runtime["packs"]))
        self.assertIn("/assets/ornaments/ export-ignore", (ROOT / ".gitattributes").read_text())


if __name__ == "__main__":
    unittest.main()
