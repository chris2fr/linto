import io
import os
import subprocess
import tarfile
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP = {".git", ".venv", "__pycache__", ".pytest_cache"}


def working_tree_archive():
    """A GitHub-style tarball (one top directory) of this working tree."""
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
        for path in sorted(ROOT.rglob("*")):
            relative = path.relative_to(ROOT)
            if any(part in SKIP for part in relative.parts) or path.suffix == ".pyc":
                continue
            archive.add(path, arcname=f"linto-main/{relative}", recursive=False)
    return buffer.getvalue()


class Handler(BaseHTTPRequestHandler):
    archive = b""
    commit = "a" * 40

    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path.endswith(".tar.gz"):
            body = self.archive
        elif self.path.endswith("install.sh"):
            body = (ROOT / "install.sh").read_bytes()
        else:
            body = self.commit.encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class BootstrapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Handler.archive = working_tree_archive()
        cls.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        Handler.commit = "a" * 40
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.env = dict(
            os.environ, LC_ALL="C", HOME=str(self.home), ZDOTDIR=str(self.home),
            XDG_DATA_HOME=str(self.home / "data"), XDG_CONFIG_HOME=str(self.home / "config"),
            LINTO_ARCHIVE_URL=f"{self.base}/linto.tar.gz", LINTO_COMMIT_URL=f"{self.base}/commit", LINTO_BOOTSTRAP_URL=f"{self.base}/install.sh",
            LINTO_SYSTEM_PREFIXES="/nonexistent", NO_PROXY="127.0.0.1", no_proxy="127.0.0.1",
        )
        self.lib = self.home / ".local" / "lib" / "linto"

    def tearDown(self):
        self.tmp.cleanup()

    def sh(self, *args, **kwargs):
        return subprocess.run(["sh", str(ROOT / "install.sh"), *args], capture_output=True, text=True,
                              env=self.env, stdin=subprocess.DEVNULL, **kwargs)

    def linto(self, *args):
        return subprocess.run([str(self.home / ".local" / "bin" / "linto"), *args], capture_output=True,
                              text=True, env=self.env, stdin=subprocess.DEVNULL)

    def marker(self, key):
        for line in (self.lib / ".linto-install").read_text(encoding="utf-8").splitlines():
            if line.startswith(f"{key}="):
                return line.split("=", 1)[1]
        return None

    def test_latest_commit(self):
        self.assertEqual(self.sh("--latest-commit").stdout.strip(), "a" * 40)

    def test_install_from_the_download_records_where_it_came_from(self):
        result = self.sh("--user", "--no-man", "--no-venv", "--shell", "bash")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("downloading chris2fr/linto", result.stderr)
        self.assertEqual(self.marker("mode"), "user")
        self.assertEqual(self.marker("commit"), "a" * 40)
        self.assertEqual(self.marker("repo"), "chris2fr/linto")
        self.assertEqual(self.marker("shells"), "bash")
        self.assertEqual(self.marker("venv"), "false")
        self.assertRegex(self.linto("--version").stdout, r"^linto \S+\n$")

    def test_a_bad_archive_is_refused(self):
        self.env["LINTO_ARCHIVE_URL"] = f"{self.base}/commit"          # not a tarball
        result = self.sh("--user", "--no-venv")
        self.assertEqual(result.returncode, 1)
        self.assertIn("cannot download or unpack", result.stderr)

    def test_update_check_and_update(self):
        self.assertEqual(self.sh("--user", "--no-man", "--no-venv", "--shell", "bash").returncode, 0)
        up_to_date = self.linto("linto", "update", "--check")
        self.assertEqual(up_to_date.returncode, 0, up_to_date.stderr)
        self.assertIn("up to date", up_to_date.stdout)

        Handler.commit = "b" * 40
        available = self.linto("linto", "update", "--check")
        self.assertEqual(available.returncode, 10)
        self.assertIn("Update available: aaaaaaa -> bbbbbbb", available.stdout)
        refused = self.linto("linto", "update")
        self.assertEqual(refused.returncode, 2)                          # no terminal, no --yes
        self.assertEqual(self.marker("commit"), "a" * 40)

        kept = self.lib / ".venv" / "extra-package-marker"
        kept.parent.mkdir()
        kept.write_text("x", encoding="utf-8")
        updated = self.linto("linto", "update", "--yes")
        self.assertEqual(updated.returncode, 0, updated.stderr)
        self.assertEqual(self.marker("commit"), "b" * 40)
        self.assertEqual((self.marker("mode"), self.marker("shells"), self.marker("man")), ("user", "bash", "false"))
        self.assertTrue(kept.exists())                                     # the environment survives
        self.assertIn("up to date", self.linto("linto", "update").stdout)

    def test_update_uses_the_fresh_bootstrap_not_the_installed_one(self):
        self.assertEqual(self.sh("--user", "--no-man", "--no-venv", "--shell", "bash").returncode, 0)
        (self.lib / "install.sh").write_text("#!/bin/sh\necho 'old bootstrap, cannot cope' >&2\nexit 1\n", encoding="utf-8")
        Handler.commit = "d" * 40
        result = self.linto("linto", "update", "--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.marker("commit"), "d" * 40)

    def test_update_falls_back_to_the_installed_bootstrap_when_the_fresh_one_is_unavailable(self):
        self.assertEqual(self.sh("--user", "--no-man", "--no-venv", "--shell", "bash").returncode, 0)
        Handler.commit = "e" * 40
        self.env["LINTO_BOOTSTRAP_URL"] = "http://127.0.0.1:9/install.sh"      # nothing listens there
        result = self.linto("linto", "update", "--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.marker("commit"), "e" * 40)

    def test_bootstrap_accepts_the_archive_layout_of_older_versions(self):
        legacy = Path(self.tmp.name) / "legacy"
        (legacy / "linto-main" / "groups" / "linto").mkdir(parents=True)
        (legacy / "linto-main" / "groups" / "linto" / "install.sh").write_text(
            "#!/bin/bash\necho legacy-installer-ran \"$@\"\n", encoding="utf-8")
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
            archive.add(legacy / "linto-main", arcname="linto-main")
        saved = Handler.archive
        Handler.archive = buffer.getvalue()
        try:
            result = self.sh("--user")
        finally:
            Handler.archive = saved
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("legacy-installer-ran --user", result.stdout)

    def test_system_installation_updates_with_the_same_choices(self):
        prefix, sysconf = self.home / "usr", self.home / "etc"
        installed = self.sh("--system", "--prefix", str(prefix), "--sysconfdir", str(sysconf), "--no-venv")
        self.assertEqual(installed.returncode, 0, installed.stderr)
        Handler.commit = "c" * 40
        result = subprocess.run([str(prefix / "bin" / "linto"), "linto", "update", "--yes"], capture_output=True,
                                text=True, env=self.env, stdin=subprocess.DEVNULL)
        self.assertEqual(result.returncode, 0, result.stderr)
        text = (prefix / "lib" / "linto" / ".linto-install").read_text(encoding="utf-8")
        self.assertIn("commit=" + "c" * 40, text)
        self.assertIn(f"sysconfdir={sysconf}", text)

    def test_a_checkout_without_an_installation_record_cannot_update(self):
        result = subprocess.run([str(ROOT / "bin" / "linto"), "linto", "update", "--check"], capture_output=True,
                                text=True, env=self.env, stdin=subprocess.DEVNULL)
        self.assertEqual(result.returncode, 1)
        self.assertIn("was not made by the installer", result.stderr)


if __name__ == "__main__":
    unittest.main()
