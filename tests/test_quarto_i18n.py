import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUARTO = ROOT / "groups" / "quarto"
COMMANDS = sorted(p.stem for p in QUARTO.glob("*.sh"))


def run(command, lang, *args):
    env = dict(os.environ, LC_ALL=lang)
    env.pop("LANGUAGE", None)
    return subprocess.run(
        [str(ROOT / "bin" / "linto"), "quarto", command, *args],
        capture_output=True, text=True, env=env,
    )


class QuartoTests(unittest.TestCase):
    def test_every_command_has_english_and_french_help(self):
        self.assertTrue(COMMANDS)
        for command in COMMANDS:
            with self.subTest(command=command):
                english = run(command, "C", "--help")
                french = run(command, "fr_FR.UTF-8", "--help")
                for result in (english, french):
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertTrue(
                        result.stdout.startswith(f"Usage: linto quarto {command} "), result.stdout
                    )
                self.assertTrue(english.stdout.isascii(), command)
                self.assertNotEqual(english.stdout, french.stdout)

    def test_errors_are_prefixed_by_the_command_and_translated(self):
        english = run("render", "C", "--bogus")
        french = run("render", "fr_FR.UTF-8", "--bogus")
        self.assertEqual(english.returncode, 2)
        self.assertTrue(english.stderr.startswith("render: unknown option: --bogus"))
        self.assertTrue(french.stderr.startswith("render: option inconnue : --bogus"))

    def test_unexpected_argument_is_a_usage_error(self):
        result = run("setup", "C", "extra")
        self.assertEqual(result.returncode, 2)
        self.assertTrue(result.stderr.startswith("setup: unexpected argument: extra"))


if __name__ == "__main__":
    unittest.main()
