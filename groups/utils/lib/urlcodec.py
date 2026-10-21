#!/usr/bin/env python3
"""Percent-encode or decode text (URL components). Usage: urlcodec.py encode|decode [OPTIONS] [TEXT ...]"""

import os
import sys
from urllib.parse import quote, quote_plus, unquote, unquote_plus

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _, fail  # noqa: E402


def encode(text: str, safe: str = "", plus: bool = False) -> str:
    return quote_plus(text, safe=safe) if plus else quote(text, safe=safe)


def decode(text: str, plus: bool = False) -> str:
    return unquote_plus(text, errors="strict") if plus else unquote(text, errors="strict")


def main(mode: str) -> int:
    if mode == "encode":
        parser = Parser("utils", "urlencode", description=_("Percent-encode text for use in a URL."))
        parser.add_argument("--safe", default="", metavar="CHARS",
                            help=_("characters to leave unencoded (default: none)"))
        parser.add_argument("--plus", action="store_true",
                            help=_("encode spaces as plus signs"))
    else:
        parser = Parser("utils", "urldecode", description=_("Decode percent-encoded text."))
        parser.add_argument("--plus", action="store_true",
                            help=_("decode + as a space"))
    parser.add_argument("text", nargs="*", metavar="TEXT",
                        help=_("text to convert (default: read standard input)"))
    args = parser.parse_args()

    if args.text:
        text = " ".join(args.text)
    elif sys.stdin.isatty():
        parser.error(_("no text: give TEXT or provide stdin"))
    else:
        text = sys.stdin.read()
        if text.endswith("\n"):
            text = text[:-1]
    try:
        result = encode(text, args.safe, args.plus) if mode == "encode" else decode(text, args.plus)
    except UnicodeDecodeError as exc:
        return fail(parser.name, _("not valid UTF-8 after decoding: {}").format(exc))
    print(result)
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("encode", "decode"):
        sys.exit("usage: urlcodec.py encode|decode [OPTIONS] [TEXT ...]")
    mode = sys.argv.pop(1)
    sys.exit(main(mode))
