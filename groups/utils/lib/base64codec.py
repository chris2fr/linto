#!/usr/bin/env python3
"""Encode or decode Base64. Usage: base64codec.py encode|decode [OPTIONS] [TEXT ...]"""

import base64
import binascii
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _, fail  # noqa: E402


def encode(data: bytes, urlsafe: bool = False, padding: bool = True) -> str:
    text = (base64.urlsafe_b64encode if urlsafe else base64.b64encode)(data).decode("ascii")
    return text if padding else text.rstrip("=")


def decode(text: str, urlsafe: bool = False) -> bytes:
    """Decode Base64, ignoring whitespace and accepting missing padding."""
    compact = "".join(text.split())
    compact += "=" * (-len(compact) % 4)
    return base64.b64decode(compact, altchars=b"-_" if urlsafe else None, validate=True)


def main(mode: str) -> int:
    name = f"base64{mode}"
    parser = Parser(
        "utils", name,
        description=_("Encode text or data as Base64.") if mode == "encode" else _("Decode Base64 text."),
    )
    parser.add_argument("--urlsafe", action="store_true",
                        help=_("use the URL-safe alphabet (- and _ instead of + and /)"))
    if mode == "encode":
        parser.add_argument("--no-padding", action="store_true", help=_("omit the = padding"))
    parser.add_argument("text", nargs="*", metavar="TEXT",
                        help=_("text to convert (default: read standard input)"))
    args = parser.parse_args()

    if args.text:
        raw = " ".join(args.text).encode("utf-8")
    elif sys.stdin.isatty():
        parser.error(_("no text: give TEXT or provide stdin"))
    else:
        raw = sys.stdin.buffer.read()

    if mode == "encode":
        print(encode(raw, args.urlsafe, not args.no_padding))
        return 0
    try:
        data = decode(raw.decode("utf-8"), args.urlsafe)
    except (binascii.Error, UnicodeDecodeError, ValueError) as exc:
        return fail(name, _("invalid Base64 input: {}").format(exc))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("encode", "decode"):
        sys.exit("usage: base64codec.py encode|decode [OPTIONS] [TEXT ...]")
    mode = sys.argv.pop(1)
    sys.exit(main(mode))
