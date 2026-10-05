import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import struct
import unittest
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/ornaments/Ukiyo-e Gallery"
PROVENANCE = json.loads((PACK / "provenance.json").read_text())
ARTWORKS = PROVENANCE["artworks"]
try:
    from PIL import Image
except ImportError:
    Image = None


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class UkiyoeAssetsTests(unittest.TestCase):
    def test_exactly_27_distinct_museum_works_and_no_extra_ornaments(self):
        files = {a["file"] for a in ARTWORKS}
        self.assertEqual(len(ARTWORKS), 27)
        self.assertEqual(len({(a["museum"], a["id"]) for a in ARTWORKS}), 27)
        self.assertEqual({p.name for p in PACK.glob("*.png")}, files)
        selection = json.loads((ROOT / "scripts/artwork/ukiyoe-selection.json").read_text())
        self.assertEqual({(a["museum"], a["id"], a["file"]) for a in ARTWORKS},
                         {(a["museum"], a["id"], a["file"]) for a in selection})

    def test_every_work_has_individual_cc0_evidence_and_museum_source_hashes(self):
        self.assertEqual({a["museum"] for a in ARTWORKS}, {"cma", "met"})
        for a in ARTWORKS:
            with self.subTest(file=a["file"]):
                self.assertEqual(a["license"], "CC0 1.0")
                self.assertEqual(a["license_url"], "https://creativecommons.org/publicdomain/zero/1.0/")
                self.assertEqual(a["rights_evidence"], {"share_license_status": "CC0"}
                                 if a["museum"] == "cma" else {"isPublicDomain": True})
                for field in ("source_sha256", "record_sha256", "sha256"):
                    self.assertRegex(a[field], r"^[a-f0-9]{64}$")
                self.assertIn(urlparse(a["image_url"]).hostname,
                              {"openaccess-cdn.clevelandart.org", "images.metmuseum.org"})
                for field in ("title", "artist", "date", "medium", "credit", "accession", "policy_url"):
                    self.assertTrue(a[field])
                self.assertIn("woodblock", a["medium"].lower())

    def test_reviewed_asset_bytes_dimensions_and_lossless_colour_format(self):
        for a in ARTWORKS:
            path = PACK / a["file"]
            with self.subTest(file=a["file"]):
                self.assertEqual(sha(path), a["sha256"])
                data = path.read_bytes()
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                w, h, depth, colour = struct.unpack(">IIBB", data[16:26])
                self.assertEqual([w, h], a["dimensions"])
                self.assertEqual((depth, colour), (8, 6))
                self.assertLessEqual(max(w, h), 840)
                x, y, aw, ah = a["art_box"]
                ow, oh = a["source_dimensions"]
                self.assertLessEqual(aw, ow)
                self.assertLessEqual(ah, oh)
                self.assertLess(abs(aw - ow * ah / oh), 2)
                self.assertTrue(0 < x < x + aw < w)
                self.assertTrue(0 < y < y + ah < h)
                self.assertIn(a["object_url"].encode(), data)

    def test_info_cards_preserve_colour_orientation_and_native_zoom(self):
        metadata = json.loads((PACK / "ornaments.json").read_text())
        self.assertEqual(set(metadata), {a["file"] for a in ARTWORKS})
        for a in ARTWORKS:
            entry = metadata[a["file"]]
            self.assertEqual(entry["mirror"], "off")
            self.assertEqual(entry["night"], "off")
            self.assertEqual(entry["tap"], "zoom")
            self.assertEqual(entry["anchor"], "bottom")
            self.assertEqual(entry["lift"], .12)
            self.assertTrue(.5 <= entry["scale"] <= 1)
            self.assertTrue(0 <= entry["pad"] <= .05)
            self.assertLessEqual(len(entry["info"].encode("utf-8")), 4000)
            for value in (a["title"], a["artist"], a["date"], a["credit"],
                          a["object_url"], a["license_url"], a["note"], a["measurements"], a["note_credit"]):
                self.assertIn(value, entry["info"])
            self.assertIn("inte museets originaltext", entry["info"])
            self.assertGreater(len(a["note"].split()), 45)
            for url in a["note_sources"]:
                self.assertIn(url, entry["info"])
                self.assertIn(urlparse(url).hostname,
                              {"clevelandart.org", "www.clevelandart.org", "www.metmuseum.org",
                               "exhibitions.bristolmuseums.org.uk"})

    def test_update_baseline_is_the_published_pack_and_artwork_is_unchanged(self):
        baseline = json.loads((ROOT / "assets/ornament-updates/ukiyoe-gallery-v1.json").read_text())
        self.assertEqual(baseline["source_commit"], "17b3970c70985c3777d8552ac89b28a48d7129a9")
        self.assertEqual(set(baseline["files"]), {"ornaments.json", "provenance.json", "README.txt", "ATTRIBUTION.txt"})
        before = json.loads(baseline["files"]["ornaments.json"])
        after = json.loads((PACK / "ornaments.json").read_text())
        for name in before:
            self.assertEqual(before[name]["lift"], 0)
            self.assertEqual(after[name]["lift"], .12)
            self.assertNotEqual(before[name]["info"], after[name]["info"])
            self.assertEqual({k: v for k, v in before[name].items() if k not in ("lift", "info")},
                             {k: v for k, v in after[name].items() if k not in ("lift", "info")})
        old_provenance = json.loads(baseline["files"]["provenance.json"])
        self.assertEqual({a["file"]: a["sha256"] for a in old_provenance["artworks"]},
                         {a["file"]: a["sha256"] for a in ARTWORKS})
        self.assertEqual(old_provenance["theme_assets"], PROVENANCE["theme_assets"])

    def test_theme_has_one_wallpaper_one_native_named_plank_and_no_forced_colours(self):
        theme = PACK / "theme"
        self.assertEqual({p.name for p in theme.iterdir()},
                         {"theme.json", "wallpaper.jpg", "plank.Hinoki.middle.png"})
        manifest = json.loads((theme / "theme.json").read_text())
        self.assertEqual(manifest["name"], "Ukiyo-e Gallery")
        self.assertEqual(manifest["plank"], "Hinoki")
        for a in PROVENANCE["theme_assets"]:
            self.assertEqual(sha(PACK / a["file"]), a["sha256"])
        data = (theme / "plank.Hinoki.middle.png").read_bytes()
        self.assertEqual(struct.unpack(">IIBB", data[16:26]), (768, 360, 8, 6))

    def test_installer_lists_every_asset_and_all_nested_theme_files(self):
        lua = (ROOT / "core/orbitui_ukiyoe_ornaments.lua").read_text()
        files = set(re.findall(r'^        "([^"]+)",$', lua, re.M))
        self.assertEqual(files, {p.relative_to(PACK).as_posix() for p in PACK.rglob("*") if p.is_file()})
        self.assertIn('ornament-ukiyoe-gallery-v1.installed', lua)
        self.assertNotIn("Store.save", lua)
        self.assertLess(sum(p.stat().st_size for p in PACK.rglob("*") if p.is_file()), 19 * 1024**2)

    def test_original_material_prompts_and_notices_are_bundled(self):
        notices = (PACK / "ATTRIBUTION.txt").read_text()
        for a in ARTWORKS:
            self.assertIn(a["file"], notices)
            self.assertIn(a["object_url"], notices)
        self.assertIn("not AndyHazz's Ko-fi pack", notices)
        prompts = json.loads((PACK / "texture-prompts.json").read_text())
        self.assertEqual(prompts["tool"], "built-in image_gen")
        self.assertEqual(len(prompts["textures"]), 2)
        for a, key in zip(prompts["textures"], ("washi_sha256", "hinoki_sha256")):
            self.assertEqual(sha(ROOT / a["source"]), PROVENANCE["texture_sources"][key])
            self.assertGreater(len(a["prompt"]), 100)
        self.assertIn("not a KOReader emulator", (ROOT / "docs/ukiyoe-gallery-preview.html").read_text())

    @unittest.skipUnless(Image, "Pillow required only for build-time pixel checks")
    def test_transparency_and_native_plank_bands(self):
        for a in ARTWORKS:
            with Image.open(PACK / a["file"]) as image:
                self.assertEqual(image.getpixel((0, 0))[3], 0)
                self.assertEqual(image.getpixel((image.width // 2, image.height - 1))[3], 255)
        with Image.open(PACK / "theme/plank.Hinoki.middle.png") as image:
            self.assertIsNone(image.crop((0, 0, 768, 120)).getbbox())
            self.assertIsNone(image.crop((0, 240, 768, 360)).getbbox())
            self.assertEqual(image.getchannel("A").crop((0, 120, 768, 240)).getextrema(), (255, 255))
            self.assertEqual(list(image.crop((0, 0, 1, 360)).getdata()),
                             list(image.crop((767, 0, 768, 360)).getdata()))

    @unittest.skipUnless(Image, "Pillow required only for build-time pixel checks")
    def test_frame_builder_never_crops_or_modifies_art_pixels(self):
        spec = importlib.util.spec_from_file_location("ukiyoe_build", ROOT / "scripts/build-ukiyoe.py")
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        for size in ((83, 147), (600, 300), (2400, 1600), (450, 1600)):
            original = Image.new("RGB", size)
            original.putdata([((x * 3) % 256, (x * 7) % 256, (x * 13) % 256)
                              for x in range(size[0] * size[1])])
            framed, (x, y, w, h) = builder.framed(original)
            expected = original.copy()
            expected.thumbnail((builder.ART_EDGE, builder.ART_EDGE), Image.Resampling.LANCZOS)
            self.assertEqual(framed.crop((x, y, x+w, y+h)).convert("RGB").tobytes(), expected.tobytes())

    @unittest.skipUnless(Image and os.environ.get("UKIYOE_SOURCE_CACHE"),
                         "Set UKIYOE_SOURCE_CACHE for the original-museum pixel audit")
    def test_every_museum_original_matches_the_actual_framed_art_pixels(self):
        cache = Path(os.environ["UKIYOE_SOURCE_CACHE"])
        for a in ARTWORKS:
            with self.subTest(file=a["file"]):
                prefix = f'{a["museum"]}-{a["id"]}'
                self.assertEqual(sha(cache / (prefix + ".jpg")), a["source_sha256"])
                self.assertEqual(sha(cache / (prefix + ".json")), a["record_sha256"])
                with Image.open(cache / (prefix + ".jpg")) as source:
                    expected = source.convert("RGB")
                    expected.thumbnail((768, 768), Image.Resampling.LANCZOS)
                with Image.open(PACK / a["file"]) as framed:
                    x, y, w, h = a["art_box"]
                    self.assertEqual(framed.crop((x, y, x+w, y+h)).convert("RGB").tobytes(),
                                     expected.tobytes())


if __name__ == "__main__":
    unittest.main()
