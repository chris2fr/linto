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
            decoded = subprocess.run([LINTO, "utils", "qrdecode", image], capture_output=True, text=True)
            self.assertEqual(decoded.stdout.strip(), "https://example.org/é?x=1")
            short = os.path.join(tmp, "short.png")      # short text must not become a Micro QR code
            subprocess.run([LINTO, "utils", "qrencode", "--no-ascii", "-o", short, "hello"], check=True,
                           capture_output=True)
            decoded = subprocess.run([LINTO, "utils", "qrdecode", short], capture_output=True, text=True)
            self.assertEqual(decoded.stdout.strip(), "hello")
            again = subprocess.run([LINTO, "utils", "qrencode", "-o", image, "x"], capture_output=True, text=True)
            self.assertEqual(again.returncode, 1)


if __name__ == "__main__":
    unittest.main()
