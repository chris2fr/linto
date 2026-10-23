#!/usr/bin/env python3
"""Count down to zero or count up from zero. Usage: stopwatch.py countdown|timer [OPTIONS]"""

import os
import math
import re
import select
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _, fail, group_configdata  # noqa: E402

UNITS = {"h": 3600, "m": 60, "s": 1}
PART = re.compile(r"(\d+(?:\.\d+)?)([hms])")


def parse_duration(text: str) -> float:
    """Seconds from "90", "1.5", "1:30", "1:02:03", "90s", "1h30m" or "1h2m3s"."""
    text = text.strip().lower()
    if re.fullmatch(r"\d+(?:\.\d+)?", text):
        return float(text)
    if re.fullmatch(r"\d+(?::\d{1,2}(?:\.\d+)?){1,2}", text):
        total = 0.0
        for part in text.split(":"):
            total = total * 60 + float(part)
        return total
    parts = PART.findall(text)
    if parts and "".join(n + u for n, u in parts) == text:
        return sum(float(n) * UNITS[u] for n, u in parts)
    raise ValueError(text)


def format_duration(seconds: float, tenths: bool = False) -> str:
    """HH:MM:SS (with .t when tenths), rounding down."""
    whole = int(seconds)
    h, rest = divmod(whole, 3600)
    m, s = divmod(rest, 60)
    text = f"{h:02d}:{m:02d}:{s:02d}"
    return text + f".{int((seconds - whole) * 10)}" if tenths else text


def show(line: str, live: bool) -> None:
    if live:
        sys.stderr.write("\r" + line + "\x1b[K")
        sys.stderr.flush()


def tclock_command(plain):
    """The tclock program (clock-tui) when it can take over: installed, on a terminal, not disabled."""
    if plain or group_configdata("utils").get("tclock", True) is False:
        return None
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        return None
    return shutil.which("tclock")


def run_tclock(command):
    """Run tclock; (seconds it ran, exit status). A status of None means it could not start."""
    started = time.monotonic()
    try:
        status = subprocess.run(command, check=False).returncode
    except OSError:
        return 0.0, None
    return time.monotonic() - started, status


def countdown(argv) -> int:
    parser = Parser("utils", "countdown", description=_(
        "Count down from a duration, then ring the terminal bell."))
    parser.add_argument("duration", metavar="DURATION", help=_(
        "seconds, M:SS, H:MM:SS, or units such as 90s, 5m, 1h30m"))
    parser.add_argument("-m", "--message", default=None, metavar="TEXT",
                        help=_("message printed when time is up (default: Time is up!)"))
    parser.add_argument("--no-bell", action="store_true", help=_("do not ring the bell"))
    parser.add_argument("--plain", action="store_true", help=_("do not hand over to tclock even if it is installed"))
    parser.add_argument("command", nargs="*", metavar="COMMAND",
                        help=_("command to run when time is up; put -- before it if it has options"))
    args = parser.parse_args(argv)
    try:
        total = parse_duration(args.duration)
    except ValueError:
        parser.error(_("invalid duration: {}").format(args.duration))
    live = sys.stderr.isatty()
    finished = False
    tclock = tclock_command(args.plain)
    if tclock:
        # tclock (clock-tui) draws the countdown; its timer takes a duration. If it ended long
        # before the time was up, the user quit it; if it failed at once, fall back to our own.
        ran, status = run_tclock([tclock, "timer", "-d", f"{max(1, math.ceil(total))}s"])
        if status is not None and (status == 0 or ran >= 1):
            if ran < total - 1:
                return 130
            finished = True
    if not finished:
        end = time.monotonic() + total
        try:
            while True:
                left = end - time.monotonic()
                if left <= 0:
                    break
                show(format_duration(left + 0.999), live)
                time.sleep(min(0.2, left))
        except KeyboardInterrupt:
            show("", live)
            print(file=sys.stderr)
            return 130
    show("", live)
    if live:
        sys.stderr.write("\r")
    print(args.message if args.message is not None else _("Time is up!"))
    if not args.no_bell:
        sys.stderr.write("\a")
        sys.stderr.flush()
    if args.command:
        try:
            return subprocess.run(args.command, check=False).returncode
        except OSError as exc:
            return fail("countdown", _("cannot run {}: {}").format(args.command[0], exc.strerror or exc)) and 127
    return 0


def timer(argv) -> int:
    parser = Parser("utils", "timer", description=_(
        "Count up from zero until interrupted with Ctrl-C, then print the elapsed time."))
    parser.add_argument("-l", "--laps", action="store_true",
                        help=_("press Enter to record a lap (needs a terminal)"))
    parser.add_argument("--plain", action="store_true", help=_("do not hand over to tclock even if it is installed"))
    args = parser.parse_args(argv)
    tclock = None if args.laps else tclock_command(args.plain)      # tclock has no laps
    if tclock:
        ran, status = run_tclock([tclock, "stopwatch"])
        if status is not None and (status == 0 or ran >= 1):
            print(format_duration(ran, tenths=True))
            return status
    live = sys.stderr.isatty()
    laps_on = args.laps and sys.stdin.isatty()
    start = last = time.monotonic()
    laps = []
    try:
        while True:
            now = time.monotonic()
            show(format_duration(now - start, tenths=True), live)
            wait = 0.1
            if laps_on:
                ready, _unused, _unused2 = select.select([sys.stdin], [], [], wait)
                if ready:
                    sys.stdin.readline()
                    now = time.monotonic()
                    laps.append((now - last, now - start))
                    last = now
                    if live:
                        sys.stderr.write("\r\x1b[K")
                    print(_("lap {}: {} (total {})").format(
                        len(laps), format_duration(laps[-1][0], True), format_duration(laps[-1][1], True)))
            else:
                time.sleep(wait)
    except KeyboardInterrupt:
        elapsed = time.monotonic() - start
        if live:
            sys.stderr.write("\r\x1b[K")
        print(format_duration(elapsed, tenths=True))
        return 0


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("countdown", "timer"):
        sys.exit("usage: stopwatch.py countdown|timer [OPTIONS]")
    mode = sys.argv.pop(1)
    sys.exit(countdown(sys.argv[1:]) if mode == "countdown" else timer(sys.argv[1:]))
