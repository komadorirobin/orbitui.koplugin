import collections
import importlib.util
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SettingsVocabularyTest(unittest.TestCase):
    def test_localized_format_parameters_are_preserved(self):
        source = (ROOT / "core/orbitui_i18n.lua").read_text()
        pairs = re.findall(r'\[("(?:\\.|[^"\\])*")\]\s*=\s*("(?:\\.|[^"\\])*")', source)
        counts = collections.Counter(json.loads(k) for k, _v in pairs)
        # These two pre-existing duplicate keys retain their old last-value
        # semantics; this settings task introduces no new duplicate entry.
        self.assertEqual({k for k, n in counts.items() if n > 1}, {"Placement", "Hardcover"})
        for raw_key, raw_value in pairs:
            english, swedish = json.loads(raw_key), json.loads(raw_value)
            with self.subTest(english=english):
                self.assertEqual(collections.Counter(re.findall(r"%(?:[1-9]|[ds])", english)),
                                 collections.Counter(re.findall(r"%(?:[1-9]|[ds])", swedish)))

    def test_static_native_vocabulary_and_utf8_byte_escapes(self):
        spec = importlib.util.spec_from_file_location("settings_vocabulary", ROOT / "scripts/settings-search.py")
        vocabulary = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(vocabulary)
        self.assertEqual(vocabulary.literal(r'"Find images\xE2\x80\xA6"'), "Find images…")
        self.assertEqual(vocabulary.literal(r'"A\nB\tC\"D"'), 'A\nB\tC"D')
        block = vocabulary.generated()
        self.assertIn(block, (ROOT / "adapters/orbitui_settings.lua").read_text())
        self.assertGreaterEqual(sum(map(len, vocabulary.terms().values())), 300)


if __name__ == "__main__":
    unittest.main()
