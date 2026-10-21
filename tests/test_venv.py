import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REAL_PYTHON = shutil.which("python3")


class VenvTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.root = self.tmp / "linto"
        shutil.copytree(
            ROOT, self.root,
            ignore=shutil.ignore_patterns(".git", ".venv", "__pycache__", "tests"),
        )
        bin_dir = self.root / ".venv" / "bin"
        bin_dir.mkdir(parents=True)
        self.marker = self.tmp / "used"
        fake = bin_dir / "python3"
        fake.write_text(f'#!/bin/sh\ntouch "{self.marker}"\nexec "{REAL_PYTHON}" "$@"\n')
        fake.chmod(0o755)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_linto(self, **env):
        full = dict(os.environ, **env)
        full.pop("LINTO_NO_VENV", None)
        full.update(env)
        return subprocess.run([str(self.root / "bin" / "linto"), "--list-groups"],
                              capture_output=True, text=True, env=full)

    def test_dispatcher_runs_with_the_environment_when_present(self):
        result = self.run_linto()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.marker.exists())

    def test_no_venv_switch(self):
        result = self.run_linto(LINTO_NO_VENV="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.marker.exists())

    def test_absent_environment_is_ignored(self):
        shutil.rmtree(self.root / ".venv")
        result = self.run_linto()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.marker.exists())

    def test_venv_command_rejects_unknown_option(self):
        result = subprocess.run([str(ROOT / "bin" / "linto"), "linto", "venv", "--bogus"],
                                capture_output=True, text=True, env=dict(os.environ, LC_ALL="C"))
        self.assertEqual(result.returncode, 2)
        self.assertTrue(result.stderr.startswith("venv: unknown option: --bogus"))


if __name__ == "__main__":
    unittest.main()
