#!/usr/bin/env python3
"""Generate random tokens and passwords from selectable character classes."""

import argparse
import os
import secrets
import string
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _  # noqa: E402

SYMBOLS = "!@#$%^&*()-_=+[]{};:,.?"


def classes(upper: bool, lower: bool, numbers: bool, symbols: bool) -> list[str]:
    """Return the enabled character classes."""
    chosen = []
    if upper:
        chosen.append(string.ascii_uppercase)
    if lower:
        chosen.append(string.ascii_lowercase)
    if numbers:
        chosen.append(string.digits)
    if symbols:
        chosen.append(SYMBOLS)
    return chosen


def generate(length: int, chosen: list[str]) -> str:
    """Return a token of LENGTH characters with at least one from each class."""
    rng = secrets.SystemRandom()
    pool = "".join(chosen)
    chars = [secrets.choice(c) for c in chosen]
    chars += [secrets.choice(pool) for _unused in range(length - len(chars))]
    rng.shuffle(chars)
    return "".join(chars)


def main() -> int:
    parser = Parser("utils", "token", description=_("Generate random tokens or passwords."))
    parser.add_argument("-l", "--length", type=int, default=32, metavar="N",
                        help=_("token length (default: 32)"))
    parser.add_argument("-n", "--count", type=int, default=1, metavar="N",
                        help=_("how many tokens to print (default: 1)"))
    for name, default, text in (
        ("upper", True, _("include upper-case letters (default: yes)")),
        ("lower", True, _("include lower-case letters (default: yes)")),
        ("numbers", True, _("include digits (default: yes)")),
        ("symbols", False, _("include symbols (default: no)")),
    ):
        parser.add_argument(f"--{name}", action=argparse.BooleanOptionalAction,
                            default=default, help=text)
    args = parser.parse_args()
    if args.length < 1:
        parser.error(_("length must be at least 1"))
    if args.count < 1:
        parser.error(_("count must be at least 1"))
    chosen = classes(args.upper, args.lower, args.numbers, args.symbols)
    if not chosen:
        parser.error(_("enable at least one character class"))
    if args.length < len(chosen):
        parser.error(_("length must be at least the number of enabled classes ({})").format(len(chosen)))
    for _unused in range(args.count):
        print(generate(args.length, chosen))
    return 0


if __name__ == "__main__":
    sys.exit(main())
