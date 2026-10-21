"""Command-line scaffolding of the bib group: the shared lib/clibase.py with group "bib"."""

import sys
from pathlib import Path

# Linto-wide helpers (lib/ at the repository root).
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "lib"))
import clibase  # noqa: E402
from clibase import _, fail, stdin_requested  # noqa: E402,F401


class Parser(clibase.Parser):
    def __init__(self, name, description=None, epilog=None, raw=False):
        super().__init__("bib", name, description, epilog, raw)
