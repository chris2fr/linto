import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = [str(ROOT / "bin" / "linto"), "linto", "install"]


def run(*args, env=None, **kwargs):
    environment = dict(os.environ, LC_ALL="C")
    environment.update(env or {})
    return subprocess.run([*INSTALL, *args], capture_output=True, text=True, env=environment,
                          stdin=subprocess.DEVNULL, **kwargs)


class InstallTests(unittest.TestCase):
    def test_a_mode_is_required_without_a_terminal(self):
        result = run()
        self.assertEqual(result.returncode, 2)
        self.assertIn("install: choose --user or --system", result.stderr)

    def test_options_are_checked_against_the_mode(self):
        self.assertIn("--prefix only applies with --system", run("--user", "--prefix", "/x").stderr)
        self.assertIn("--shell only applies with --user", run("--system", "--shell", "fish").stderr)
        self.assertIn("unsupported shell 'csh'", run("--user", "--shell", "csh").stderr)

    def test_help_and_french_help(self):
        english = run("--help")
        french = run("--help", env={"LC_ALL": "fr_FR.UTF-8"})
        self.assertTrue(english.stdout.startswith("Usage: linto linto install"))
        self.assertNotEqual(english.stdout, french.stdout)

    def test_system_install_into_a_prefix(self):
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / "usr"
            for _ in range(2):                                       # a second run upgrades in place
                result = run("--system", "--prefix", str(prefix))
                self.assertEqual(result.returncode, 0, result.stderr)
            env = {"PATH": f"{prefix / 'bin'}:{os.environ['PATH']}"}
            version = subprocess.run(["linto", "--version"], capture_output=True, text=True,
                                     env=dict(os.environ, **env))
            self.assertRegex(version.stdout, r"^linto \S+\n$")
            token = subprocess.run(["linto-utils-uuid"], capture_output=True, text=True,
                                   env=dict(os.environ, **env))
            self.assertEqual(token.returncode, 0, token.stderr)
            for path in ("share/bash-completion/completions/linto", "share/zsh/site-functions/_linto",
                         "share/fish/vendor_completions.d/linto.fish", "share/man/man1/linto.1"):
                self.assertTrue((prefix / path).exists(), path)
            self.assertFalse((prefix / "lib" / "linto" / ".git").exists())
            self.assertFalse((prefix / "lib" / "linto" / "tests").exists())

    def test_system_install_refuses_to_replace_a_foreign_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "lib" / "linto").mkdir(parents=True)
            result = run("--system", "--prefix", directory)
            self.assertEqual(result.returncode, 1)
            self.assertIn("not a Linto installation", result.stderr)


if __name__ == "__main__":
    unittest.main()
