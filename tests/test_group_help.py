import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINTO = str(ROOT / "bin" / "linto")
GROUPS = ("utils", "beta", "launch", "linto", "web")


def run(lang, *args):
    env = dict(os.environ, LC_ALL=lang)
    env.pop("LANGUAGE", None)
    return subprocess.run([LINTO, *args], capture_output=True, text=True, env=env)


def commands(group):
    out = run("C", "--list-commands", group)
    return out.stdout.split()


class GroupHelpTests(unittest.TestCase):
    def test_every_command_has_english_and_french_help(self):
        for group in GROUPS:
            names = commands(group)
            self.assertTrue(names, group)
            for command in names:
                with self.subTest(group=group, command=command):
                    english = run("C", group, command, "--help")
                    french = run("fr_FR.UTF-8", group, command, "--help")
                    for result in (english, french):
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertTrue(
                            result.stdout.startswith(f"Usage: linto {group} {command}"),
                            result.stdout,
                        )
                    self.assertTrue(english.stdout.isascii())
                    self.assertNotEqual(english.stdout, french.stdout)

    def test_unknown_option_is_a_translated_usage_error(self):
        for group in GROUPS:
            for command in commands(group):
                with self.subTest(group=group, command=command):
                    english = run("C", group, command, "--bogus-option", "1")
                    french = run("fr_FR.UTF-8", group, command, "--bogus-option", "1")
                    self.assertEqual(english.returncode, 2, english.stderr)
                    self.assertTrue(english.stderr.startswith(f"{command}: "), english.stderr)
                    self.assertNotEqual(english.stderr, french.stderr)


class ZedWaitTests(unittest.TestCase):
    """linto launch zed -w/--wait is passed to zeditor."""

    def run_zed(self, *args):
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            fake = home / "bin" / "zeditor"
            fake.parent.mkdir()
            log = home / "zeditor.log"
            fake.write_text(f'#!/bin/sh\necho "$@" >> "{log}"\n')
            fake.chmod(0o755)
            env = dict(os.environ, HOME=str(home), LC_ALL="C", PATH=f"{fake.parent}:{os.environ['PATH']}")
            result = subprocess.run([LINTO, "launch", "zed", "-u", str(home), *args, str(home)],
                                    capture_output=True, text=True, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            return log.read_text().strip()

    def test_wait_is_passed_to_zeditor(self):
        for flag in ("-w", "--wait"):
            self.assertIn("--wait", self.run_zed(flag).split())

    def test_no_wait_by_default(self):
        self.assertNotIn("--wait", self.run_zed().split())

    def test_wait_works_with_new(self):
        words = self.run_zed("-n", "-w").split()
        self.assertIn("--new", words)
        self.assertIn("--wait", words)


if __name__ == "__main__":
    unittest.main()
