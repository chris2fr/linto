import importlib.util
import os
import signal
import subprocess
import sys
import tempfile
import time
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


def run_on_terminal(args, env, timeout=20):
    """Run linto with a pseudo-terminal as stdin, stdout and stderr; return (status, output)."""
    import pty
    import select
    master, slave = pty.openpty()
    proc = subprocess.Popen([LINTO, *args], stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True)
    os.close(slave)
    output = b""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        ready, _unused, _unused2 = select.select([master], [], [], 0.2)
        if ready:
            try:
                chunk = os.read(master, 65536)
            except OSError:
                break
            if not chunk:
                break
            output += chunk
        elif proc.poll() is not None:
            break
    os.close(master)
    return proc.wait(timeout=5), output.decode("utf-8", "replace")


class TclockTests(unittest.TestCase):
    """countdown and timer hand over to tclock (clock-tui) when it is installed."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.log = self.dir / "tclock.log"
        fake = self.dir / "bin" / "tclock"
        fake.parent.mkdir()
        fake.write_text(
            '#!/bin/sh\necho "$@" >> "$TCLOCK_LOG"\n[ -n "$TCLOCK_QUIT" ] && exit 0\n'
            'case "$1" in timer) n=${3%s}; sleep "$n" ;; stopwatch) sleep 1 ;; esac\n')
        fake.chmod(0o755)
        self.env = dict(os.environ, LC_ALL="C", TCLOCK_LOG=str(self.log), HOME=str(self.dir),
                        XDG_CONFIG_HOME=str(self.dir / "config"), PATH=f"{fake.parent}:{os.environ['PATH']}")

    def tearDown(self):
        self.tmp.cleanup()

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_countdown_hands_over_to_tclock_timer(self):
        status, output = run_on_terminal(["utils", "countdown", "2s", "--no-bell", "-m", "done"], self.env)
        self.assertEqual(status, 0, output)
        self.assertEqual(self.calls(), ["timer -d 2s"])
        self.assertIn("done", output)

    def test_quitting_tclock_early_is_an_interruption(self):
        status, output = run_on_terminal(["utils", "countdown", "30s", "--no-bell", "-m", "done"],
                                         dict(self.env, TCLOCK_QUIT="1"))
        self.assertEqual(status, 130, output)
        self.assertNotIn("done", output)

    def test_plain_and_no_terminal_keep_the_builtin_display(self):
        status, output = run_on_terminal(["utils", "countdown", "0.2s", "--no-bell", "--plain"], self.env)
        self.assertEqual((status, self.calls()), (0, []), output)
        piped = subprocess.run([LINTO, "utils", "countdown", "0.2s", "--no-bell"], capture_output=True,
                               text=True, env=self.env, stdin=subprocess.DEVNULL)
        self.assertEqual((piped.returncode, self.calls()), (0, []), piped.stderr)

    def test_configuration_can_turn_tclock_off(self):
        (self.dir / "config" / "linto").mkdir(parents=True)
        (self.dir / "config" / "linto" / "config.yml").write_text(
            "groups:\n  utils:\n    configdata:\n      tclock: false\n", encoding="utf-8")
        status, output = run_on_terminal(["utils", "countdown", "0.2s", "--no-bell"], self.env)
        self.assertEqual((status, self.calls()), (0, []), output)

    def test_timer_hands_over_to_tclock_stopwatch_and_prints_the_time(self):
        status, output = run_on_terminal(["utils", "timer"], self.env)
        self.assertEqual(status, 0, output)
        self.assertEqual(self.calls(), ["stopwatch"])
        self.assertRegex(output, r"00:00:01\.\d")
        laps, _unused = run_on_terminal(["utils", "timer", "--laps", "--help"], self.env)
        self.assertEqual(self.calls(), ["stopwatch"])                  # --laps/--help never start tclock
