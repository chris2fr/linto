import os
from pathlib import Path
import pty
import select
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
DOWN = b"\x1bOB"  # application-mode cursor down, as sent after curses enables keypad


def run_in_terminal(arguments, keys):
    """Run linto on a pseudo-terminal, sending each key in turn; return the output."""
    pid, descriptor = pty.fork()
    if pid == 0:
        os.environ.update(LINTO_MDVIEWER="cat", TERM="xterm")
        os.execv(str(ROOT / "bin" / "linto"), ["linto", *arguments])
    output = b""

    def drain(seconds):
        nonlocal output
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            ready, _, _ = select.select([descriptor], [], [], 0.05)
            if ready:
                try:
                    chunk = os.read(descriptor, 65536)
                except OSError:
                    return False
                if not chunk:
                    return False
                output += chunk
        return True

    drain(1.0)
    for key in keys:
        os.write(descriptor, key)
        drain(0.8)
    drain(0.5)
    try:
        os.close(descriptor)
    except OSError:
        pass
    os.waitpid(pid, 0)
    return output.decode(errors="replace")


class HelpMenuTests(unittest.TestCase):
    def test_arrow_keys_and_enter_open_the_selected_group(self):
        output = run_in_terminal(["help"], [DOWN, DOWN, b"\r", b"q"])
        self.assertIn("Select a group", output)
        self.assertIn("Commands in group 'launch':", output)
        self.assertIn("Select a command", output)
        self.assertIn("linto help launch zed", output)

    def test_q_cancels_without_opening_anything(self):
        output = run_in_terminal(["help"], [b"q"])
        self.assertIn("Select a group", output)
        self.assertNotIn("Commands in group", output)


if __name__ == "__main__":
    unittest.main()
