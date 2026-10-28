import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_package", ROOT / "scripts/release-package.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackageTests(unittest.TestCase):
    def test_only_component_po_source_location_comments_are_omitted(self):
        original = (
            '# Copyright (C) Contributors\r\n'
            '# License and translator credits must stay.\r\n'
            '#. Context for translators\r\n'
            '#, fuzzy, c-format\r\n'
            '#| msgid "Previous text"\r\n'
            '#~ msgid "Obsolete text"\r\n'
            '#: lib/example.lua:12 lib/other.lua:34\r\n'
            ' \t#: lib/indented.lua:56\r\n'
            'msgid ""\r\n'
            'msgstr ""\r\n'
            '"Language: sv\\n"\r\n'
            '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\r\n'
            '\r\n'
            'msgctxt "#: literal context"\r\n'
            'msgid "#: literal message"\r\n'
            'msgid_plural "#: literal messages"\r\n'
            'msgstr[0] "Svensk text: åäö"\r\n'
            'msgstr[1] "#: literal translated text"\r\n'
            '"#: literal continuation"\r\n'
            '\r\n'
            '#: final/location.lua:78'
        ).encode('utf-8')
        expected = original.replace(b'#: lib/example.lua:12 lib/other.lua:34\r\n', b'')
        expected = expected.replace(b' \t#: lib/indented.lua:56\r\n', b'')
        expected = expected.replace(b'#: final/location.lua:78', b'')
        for component in ('bookshelf', 'simpleui'):
            path = f'components/{component}/locale/sv.po'
            with self.subTest(path=path):
                result = package.runtime_bytes(path, original)
                self.assertEqual(result, expected)
                self.assertEqual(package.runtime_bytes(path, result), result)
        for path in ('locale/sv.po', 'components/other/locale/sv.po',
                     'components/bookshelf/locale/sv.pot',
                     'components/simpleui/locale/nested/sv.po',
                     'components/simpleui/locale/sv.po.lua', 'main.lua', 'LICENSE'):
            with self.subTest(path=path):
                self.assertEqual(package.runtime_bytes(path, original), original)
        self.assertEqual(package.runtime_bytes('components/simpleui/locale/empty.po', b''), b'')
        self.assertEqual(package.runtime_bytes('components/simpleui/locale/binary.po',
                                               b'\xff\x00\r\n#: source.lua:1\n'), b'\xff\x00\r\n')

    def test_sealed_catalog_sizes_hashes_and_other_files_describe_optimized_bytes(self):
        catalog = b'# Copyright and license\n#: main.lua:12\nmsgid "Book"\nmsgstr "Bok"\n'
        optimized = catalog.replace(b'#: main.lua:12\n', b'')
        files = {'VERSION': b'0.1.0-beta.15\n', 'main.lua': b'return {}\n',
                 'components/bookshelf/locale/sv.po': catalog,
                 'components/simpleui/locale/sv.po': catalog,
                 'assets/unrelated.po': catalog, 'LICENSE': b'License\n'}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / package.ASSET
            with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
                for name, data in files.items():
                    archive.writestr(package.PREFIX + name, data)
            package.seal(path)
            with zipfile.ZipFile(path) as archive:
                manifest = json.loads(archive.read(package.PREFIX + 'manifest.json'))
                self.assertEqual({entry['path'] for entry in manifest['files']}, set(files))
                for entry in manifest['files']:
                    name = entry['path']
                    expected = optimized if name.startswith('components/') else files[name]
                    self.assertEqual(archive.read(package.PREFIX + name), expected)
                    self.assertEqual(entry['size'], len(expected))
                    self.assertEqual(entry['sha256'], hashlib.sha256(expected).hexdigest())
                    self.assertEqual(archive.getinfo(package.PREFIX + name).file_size, len(expected))
            checksum = path.with_name(path.name + '.sha256').read_text().split()
            self.assertEqual(checksum, [hashlib.sha256(path.read_bytes()).hexdigest(), package.ASSET])

    @unittest.skipUnless(shutil.which('msgfmt'), 'gettext is required for catalog semantic validation')
    def test_all_current_catalogs_compile_identically_after_optimization(self):
        catalogs = sorted(ROOT.glob('components/*/locale/*.po'))
        self.assertTrue(catalogs)
        saved = 0
        with tempfile.TemporaryDirectory() as directory:
            compiled = Path(directory) / 'catalog.mo'
            for path in catalogs:
                with self.subTest(catalog=str(path.relative_to(ROOT))):
                    original = path.read_bytes()
                    optimized = package.runtime_bytes(path.relative_to(ROOT).as_posix(), original)
                    outputs = []
                    for data in (original, optimized):
                        subprocess.run(['msgfmt', '--check', '--no-hash', '-o', str(compiled), '-'],
                                       input=data, capture_output=True, check=True)
                        outputs.append(compiled.read_bytes())
                    self.assertEqual(outputs[0], outputs[1])
                    self.assertEqual(path.read_bytes(), original)
                    saved += len(original) - len(optimized)
        self.assertGreater(saved, 0)

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

    def test_build_limits_match_the_runtime_ota_contract(self):
        self.assertEqual((package.MAX_ZIP, package.MAX_TOTAL, package.MAX_FILE),
                         (128 * 1024**2, 256 * 1024**2, 32 * 1024**2))
        self.assertEqual((package.MAX_FILES, package.MAX_MANIFEST), (2000, 1024**2))
        limits = ", ".join(f"{value // 1024**2} * 1024 * 1024" for value in
                           (package.MAX_ZIP, package.MAX_TOTAL, package.MAX_FILE))
        self.assertIn("local MAX_ZIP, MAX_TOTAL, MAX_FILE = " + limits,
                      (ROOT / "core/orbitui_ota.lua").read_text())


if __name__ == "__main__":
    unittest.main()
