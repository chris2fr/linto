#!/usr/bin/env python3
"""Optional Python packages, installed into Linto's own environment on first use.

Each extra NAME is a requirements file, requirements/NAME.txt. Its first line
may say "# download: about N MB" to tell the user what is about to happen.
"""

import importlib
import os
import re
import subprocess
import sys
import sysconfig
from pathlib import Path

from i18n import _

REQUIREMENTS = Path(__file__).resolve().parent.parent / "requirements"


def extra_file(name: str) -> Path:
    return REQUIREMENTS / f"{name}.txt"


def available_extras() -> list[str]:
    return sorted(p.stem for p in REQUIREMENTS.glob("*.txt"))


def download_note(name: str) -> str:
    """The "# download:" hint of an extra, or an empty string."""
    try:
        text = extra_file(name).read_text(encoding="utf-8")
    except OSError:
        return ""
    found = re.search(r"^#\s*download:\s*(.+)$", text, re.M)
    return found.group(1).strip() if found else ""


def in_environment() -> bool:
    """True when running in a virtual environment (Linto's own, normally)."""
    return sys.prefix != sys.base_prefix


def environment_is_writable() -> bool:
    return os.access(sysconfig.get_paths()["purelib"], os.W_OK)


def command_for(name: str) -> str:
    return f"linto linto venv --extra {name}"


def install(name: str) -> bool:
    """pip-install the extra into the running environment."""
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "-r", str(extra_file(name))],
        check=False,
    )
    importlib.invalidate_caches()
    return result.returncode == 0


def offer_install(name: str, what: str, prog: str) -> bool:
    """Install the extra NAME if the user agrees; explain how to otherwise. True when installed."""
    if not extra_file(name).is_file():
        print(f"{prog}: {_('unknown extra: {}').format(name)}", file=sys.stderr)
        return False
    hint = _("{} needs the optional packages {}. Install them with: {}").format(what, name, command_for(name))
    if not in_environment():
        print(f"{prog}: {_('Linto has no Python environment of its own.')} {hint}", file=sys.stderr)
        return False
    if not environment_is_writable():
        print(f"{prog}: {_('the Python environment is read-only, so run it with the right privileges.')} {hint}",
              file=sys.stderr)
        return False
    if not (sys.stdin.isatty() and sys.stderr.isatty()):
        print(f"{prog}: {hint}", file=sys.stderr)
        return False
    note = download_note(name)
    question = _("{} needs the optional packages {} ({}). Download and install them now? [y/N] ").format(
        what, name, note or _("size unknown"))
    print(f"{prog}: {question}", end="", file=sys.stderr, flush=True)
    if input().strip().lower() not in ("y", "yes", "o", "oui"):
        return False
    if not install(name):
        print(f"{prog}: {_('the installation failed.')} {hint}", file=sys.stderr)
        return False
    return True


def ensure(module: str, name: str, what: str, prog: str) -> bool:
    """True when MODULE imports, after offering to install the extra NAME if it does not."""
    try:
        importlib.import_module(module)
        return True
    except ImportError:
        pass
    if not offer_install(name, what, prog):
        return False
    try:
        importlib.import_module(module)
        return True
    except ImportError:
        return False
