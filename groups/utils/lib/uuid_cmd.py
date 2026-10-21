#!/usr/bin/env python3
"""Generate UUIDs (versions 1, 4 and 7)."""

import os
import secrets
import sys
import time
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _  # noqa: E402


def uuid7() -> uuid.UUID:
    """Time-ordered UUID: 48-bit Unix milliseconds followed by random bits (RFC 9562)."""
    millis = time.time_ns() // 1_000_000
    value = (millis & (2**48 - 1)) << 80 | secrets.randbits(80)
    value = (value & ~(0xF << 76)) | (0x7 << 76)          # version 7
    value = (value & ~(0x3 << 62)) | (0x2 << 62)          # variant 10
    return uuid.UUID(int=value)


def generate(version: int) -> uuid.UUID:
    if version == 1:
        return uuid.uuid1()
    if version == 7:
        return uuid7()
    return uuid.uuid4()


def main() -> int:
    parser = Parser("utils", "uuid", description=_("Generate UUIDs."))
    parser.add_argument("-n", "--count", type=int, default=1, metavar="N",
                        help=_("how many UUIDs to print (default: 1)"))
    parser.add_argument("-v", "--version", type=int, choices=(1, 4, 7), default=4,
                        metavar="VERSION",
                        help=_("UUID version: 1 (time and host), 4 (random) or 7 (time-ordered); default: 4"))
    parser.add_argument("-u", "--upper", action="store_true", help=_("print in upper case"))
    parser.add_argument("--no-hyphens", action="store_true", help=_("print without hyphens"))
    args = parser.parse_args()
    if args.count < 1:
        parser.error(_("count must be at least 1"))
    for _unused in range(args.count):
        text = str(generate(args.version))
        if args.no_hyphens:
            text = text.replace("-", "")
        print(text.upper() if args.upper else text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
