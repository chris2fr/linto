import importlib.util
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "groups" / "utils" / "lib"
LINTO = str(ROOT / "bin" / "linto")


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, LIB / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


stopwatch = load("stopwatch", "stopwatch.py")


class DurationTests(unittest.TestCase):
    def test_parse(self):
        cases = {"90": 90, "1.5": 1.5, "1:30": 90, "1:02:03": 3723, "90s": 90, "5m": 300, "1h2m3s": 3723}
        for text, seconds in cases.items():
            self.assertEqual(stopwatch.parse_duration(text), seconds, text)

    def test_invalid(self):
        for text in ("", "1x", "m5", "1:2:3:4", "-3"):
            with self.assertRaises(ValueError, msg=text):
                stopwatch.parse_duration(text)

    def test_format(self):
        self.assertEqual(stopwatch.format_duration(3723.46), "01:02:03")
        self.assertEqual(stopwatch.format_duration(3723.46, tenths=True), "01:02:03.4")


class CommandTests(unittest.TestCase):
    def test_countdown_prints_message(self):
        result = subprocess.run([LINTO, "utils", "countdown", "0.2s", "-m", "go", "--no-bell"],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual((result.returncode, result.stdout), (0, "go\n"))

    def test_countdown_runs_command_and_returns_its_status(self):
        result = subprocess.run([LINTO, "utils", "countdown", "0.1s", "--no-bell", "-m", "go",
                                 "--", "sh", "-c", "echo ran; exit 3"],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual((result.returncode, result.stdout), (3, "go\nran\n"))

    def test_countdown_missing_command(self):
        result = subprocess.run([LINTO, "utils", "countdown", "0.1s", "--no-bell", "no-such-command-xyz"],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 127, result.stderr)

    def test_timer_prints_elapsed_on_interrupt(self):
        proc = subprocess.Popen([LINTO, "utils", "timer"], stdout=subprocess.PIPE, text=True,
                                stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
        time.sleep(1.0)
        proc.send_signal(signal.SIGINT)
        out, _unused = proc.communicate(timeout=10)
        self.assertRegex(out, r"^00:00:0[0-2]\.\d\n$")


@unittest.skipUnless(
    importlib.util.find_spec("segno") and importlib.util.find_spec("cv2"), "segno and cv2 are required"
)
class QrTests(unittest.TestCase):
    def test_round_trip_and_ascii(self):
        with tempfile.TemporaryDirectory() as tmp:
            image = os.path.join(tmp, "q.png")
            encoded = subprocess.run([LINTO, "utils", "qrencode", "-o", image, "https://example.org/é?x=1"],
                                     capture_output=True, text=True)
            self.assertEqual(encoded.returncode, 0, encoded.stderr)
            self.assertIn("█", encoded.stdout)
            decoded = subprocess.run([LINTO, "utils", "qrdecode", "--backend", "opencv", image], capture_output=True, text=True)
            self.assertEqual(decoded.stdout.strip(), "https://example.org/é?x=1")
            short = os.path.join(tmp, "short.png")      # short text must not become a Micro QR code
            subprocess.run([LINTO, "utils", "qrencode", "--no-ascii", "-o", short, "hello"], check=True,
                           capture_output=True)
            decoded = subprocess.run([LINTO, "utils", "qrdecode", "--backend", "opencv", short], capture_output=True, text=True)
            self.assertEqual(decoded.stdout.strip(), "hello")
            again = subprocess.run([LINTO, "utils", "qrencode", "-o", image, "x"], capture_output=True, text=True)
            self.assertEqual(again.returncode, 1)


if __name__ == "__main__":
    unittest.main()


class QrBackendTests(unittest.TestCase):
    """qrdecode backends, with a stand-in zbarimg."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.fake = Path(self.tmp.name) / "bin"
        self.fake.mkdir()
        zbar = self.fake / "zbarimg"
        zbar.write_text('#!/bin/sh\n[ "$1" = --quiet ] || exit 1\necho "decoded by zbar"\n')
        zbar.chmod(0o755)
        self.image = Path(self.tmp.name) / "q.png"
        self.image.write_bytes(b"not really an image")

    def tearDown(self):
        self.tmp.cleanup()

    def decode(self, *args, path=None, config=None):
        env = dict(os.environ, LC_ALL="C", PATH=path if path is not None else f"{self.fake}:{os.environ['PATH']}")
        if config is not None:
            home = Path(self.tmp.name) / "home"
            (home / ".config" / "linto").mkdir(parents=True, exist_ok=True)
            (home / ".config" / "linto" / "config.yml").write_text(config, encoding="utf-8")
            env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"))
        return subprocess.run([LINTO, "utils", "qrdecode", *args, str(self.image)], capture_output=True, text=True,
                              env=env, stdin=subprocess.DEVNULL)

    def test_zbar_is_the_default_backend_and_opencv_is_not_a_silent_fallback(self):
        import shutil
        if shutil.which("zbarimg"):
            self.skipTest("a real zbarimg is installed")
        result = self.decode(path=os.environ["PATH"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("install zbar-tools", result.stderr)
        self.assertIn("--backend opencv", result.stderr)

    def test_zbar_backend_is_used_when_present(self):
        result = self.decode()
        self.assertEqual((result.returncode, result.stdout), (0, "decoded by zbar\n"), result.stderr)

    def test_backend_can_be_forced_and_a_missing_one_is_reported(self):
        self.assertIn("zbar", self.decode("--backend", "zbar").stdout)
        import shutil
        if shutil.which("zbarimg"):
            self.skipTest("a real zbarimg is installed")
        without = self.decode("--backend", "zbar", path=os.environ["PATH"])
        self.assertEqual(without.returncode, 1)
        self.assertIn("zbarimg is not installed", without.stderr)

    def test_configured_order_decides_the_backend(self):
        config = "groups:\n  utils:\n    configdata:\n      qrdecode:\n        backends: [opencv, zbar]\n"
        result = self.decode(config=config)
        # opencv, first in the order, is tried before zbar when it is available.
        if importlib.util.find_spec("cv2"):
            self.assertNotIn("decoded by zbar", result.stdout)
        else:
            self.assertIn("decoded by zbar", result.stdout)


class ExtrasTests(unittest.TestCase):
    def setUp(self):
        sys_path = str(ROOT / "lib")
        import sys
        if sys_path not in sys.path:
            sys.path.insert(0, sys_path)
        import extras
        self.extras = extras

    def test_extras_are_listed_with_their_download_note(self):
        self.assertIn("qr-opencv", self.extras.available_extras())
        self.assertIn("150 MB", self.extras.download_note("qr-opencv"))
        self.assertEqual(self.extras.download_note("no-such-extra"), "")

    def test_ensure_reports_how_to_install_without_a_terminal(self):
        import contextlib
        import io
        error = io.StringIO()
        with contextlib.redirect_stderr(error):
            ok = self.extras.ensure("module_that_does_not_exist_xyz", "qr-opencv", "Something", "prog")
        self.assertFalse(ok)
        self.assertIn("linto linto venv --extra qr-opencv", error.getvalue())

    def test_ensure_is_quiet_when_the_module_is_there(self):
        self.assertTrue(self.extras.ensure("json", "qr-opencv", "Something", "prog"))
