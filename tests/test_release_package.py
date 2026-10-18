import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_package", ROOT / "scripts/release-package.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackageTests(unittest.TestCase):
    def test_sealed_manifest_and_checksum_describe_exact_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / package.ASSET
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(package.PREFIX + "VERSION", "0.1.0-alpha.2\n")
                archive.writestr(package.PREFIX + "main.lua", "return {}\n")
            package.seal(path)
            with zipfile.ZipFile(path) as archive:
                manifest = json.loads(archive.read(package.PREFIX + "manifest.json"))
                self.assertEqual(manifest["version"], "0.1.0-alpha.2")
                self.assertEqual(manifest["bootstrap_api"], 1)
                for entry in manifest["files"]:
                    data = archive.read(package.PREFIX + entry["path"])
                    self.assertEqual(len(data), entry["size"])
                    self.assertEqual(hashlib.sha256(data).hexdigest(), entry["sha256"])
            checksum = path.with_name(path.name + ".sha256").read_text().split()
            self.assertEqual(checksum, [hashlib.sha256(path.read_bytes()).hexdigest(), package.ASSET])

    def test_unsafe_paths_duplicates_and_links_are_rejected(self):
        for name, mode in [("../outside", 0o100644), (".orbitui-active", 0o100644),
                           ("link", 0o120777), ("VERSION", 0o100644)]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / package.ASSET
                with zipfile.ZipFile(path, "w") as archive:
                    archive.writestr(package.PREFIX + "VERSION", "0.1.0-alpha.2\n")
                    item = zipfile.ZipInfo(package.PREFIX + name)
                    item.external_attr = mode << 16
                    archive.writestr(item, "bad")
                with self.assertRaises(AssertionError):
                    package.seal(path)

    def test_ota_limits_reject_uninstallable_archives_before_sealing(self):
        for limit in ("MAX_ZIP", "MAX_TOTAL", "MAX_FILE", "MAX_FILES", "MAX_MANIFEST"):
            with self.subTest(limit=limit), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / package.ASSET
                with zipfile.ZipFile(path, "w") as archive:
                    archive.writestr(package.PREFIX + "VERSION", "0.1.0-alpha.2\n")
                    archive.writestr(package.PREFIX + "main.lua", "return {}\n")
                original = path.read_bytes()
                with patch.object(package, limit, 1), self.assertRaises(AssertionError):
                    package.seal(path)
                self.assertEqual(path.read_bytes(), original)
                self.assertFalse(path.with_name(path.name + ".sha256").exists())
                self.assertFalse(path.with_suffix(".tmp").exists())

    def test_build_limits_match_the_installed_ota_contract(self):
        self.assertEqual((package.MAX_ZIP, package.MAX_TOTAL, package.MAX_FILE),
                         (64 * 1024**2, 128 * 1024**2, 32 * 1024**2))
        self.assertEqual((package.MAX_FILES, package.MAX_MANIFEST), (2000, 1024**2))


if __name__ == "__main__":
    unittest.main()
