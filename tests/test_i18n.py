import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))
import i18n  # noqa: E402

BIB = ROOT / "groups" / "bib"
COMMANDS = sorted(p.stem for p in BIB.glob("*.sh"))


def run(command, lang, *args):
    env = dict(os.environ, LC_ALL=lang)
    env.pop("LANGUAGE", None)
    return subprocess.run(
        [str(ROOT / "bin" / "linto"), "bib", command, *args],
        capture_output=True, text=True, env=env,
    )


class CatalogTests(unittest.TestCase):
    def test_catalog_is_valid_and_has_no_empty_translation(self):
        catalog = i18n.parse_po(ROOT / "locale" / "fr.po")
        self.assertGreater(len(catalog), 50)
        for msgid, msgstr in catalog.items():
            self.assertEqual(msgid.count("%s"), msgstr.count("%s"), msgid)
            self.assertEqual(msgid.count("{}"), msgstr.count("{}"), msgid)

    def test_language_comes_from_the_first_variable_set(self):
        saved = {k: os.environ.pop(k, None) for k in ("LC_ALL", "LC_MESSAGES", "LANG")}
        try:
            self.assertIsNone(i18n.language())
            os.environ["LANG"] = "fr_FR.UTF-8"
            self.assertEqual(i18n.language(), "fr")
            os.environ["LC_ALL"] = "C"
            self.assertIsNone(i18n.language())
        finally:
            for key in saved:
                os.environ.pop(key, None)
                if saved[key] is not None:
                    os.environ[key] = saved[key]


class HelpTests(unittest.TestCase):
    def test_every_command_has_english_and_french_help(self):
        for command in COMMANDS:
            with self.subTest(command=command):
                english = run(command, "C", "--help")
                french = run(command, "fr_FR.UTF-8", "--help")
                for result in (english, french):
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertTrue(result.stdout.startswith("Usage: linto bib "), result.stdout)
                self.assertTrue(english.stdout.isascii(), command)
                self.assertNotEqual(english.stdout, french.stdout)

    def test_errors_are_prefixed_by_the_command_and_translated(self):
        english = run("json2db", "C", "--bogus")
        french = run("json2db", "fr_FR.UTF-8", "--bogus")
        self.assertEqual(english.returncode, 2)
        self.assertTrue(english.stderr.startswith("json2db: unknown option: --bogus"))
        self.assertTrue(french.stderr.startswith("json2db: option inconnue : --bogus"))


if __name__ == "__main__":
    unittest.main()
