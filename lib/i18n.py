#!/usr/bin/env python3
"""Message translation for Linto, from locale/<lang>.po catalogs.

Source strings are English. The language comes from LC_ALL, LC_MESSAGES or
LANG (first one set); a string with no translation is returned unchanged.
Option, command and parameter names are never translated.

Usage from Python:  from i18n import _
Usage from shell:   python3 lib/i18n.py MSGID     (prints the translation)
"""

import os
import re
import sys
from pathlib import Path

LOCALE_DIR = Path(__file__).resolve().parent.parent / "locale"
_ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}
_catalog = None


def language():
    """Two-letter language code of the environment, or None for C/POSIX/English."""
    for name in ("LC_ALL", "LC_MESSAGES", "LANG"):
        value = os.environ.get(name)
        if value:
            code = re.split(r"[_.@]", value, maxsplit=1)[0].lower()
            return None if code in ("", "c", "posix", "en") else code
    return None


def _unquote(text):
    return re.sub(r"\\(.)", lambda m: _ESCAPES.get(m.group(1), m.group(1)), text[1:-1])


def parse_po(path):
    """Return {msgid: msgstr} for the non-empty translations of a .po file."""
    catalog, field, msgid, msgstr = {}, None, "", ""

    def flush():
        if msgid and msgstr:
            catalog[msgid] = msgstr

    for line in Path(path).read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("msgid "):
            flush()
            field, msgid, msgstr = "id", _unquote(line[6:]), ""
        elif line.startswith("msgstr "):
            field, msgstr = "str", _unquote(line[7:])
        elif line.startswith('"') and field:
            if field == "id":
                msgid += _unquote(line)
            else:
                msgstr += _unquote(line)
    flush()
    return catalog


def translate(msgid):
    global _catalog
    if _catalog is None:
        lang = language()
        po = LOCALE_DIR / f"{lang}.po" if lang else None
        _catalog = parse_po(po) if po and po.is_file() else {}
    return _catalog.get(msgid, msgid)


_ = translate

if __name__ == "__main__":
    sys.stdout.write(translate(sys.argv[1]))
