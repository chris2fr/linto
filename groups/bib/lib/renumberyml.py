#!/usr/bin/env python3
"""
renumberyml.py — Renumber YAML entries so that each value equals its line number.

Usage:
    python renumberyml.py input.yml [output.yml]

If output.yml is omitted, the result is written to standard output.
"""

import re
import sys


def renumber_yaml(input_path, output_path=None):
    # Regex: optional leading spaces, a double-quoted key, optional spaces,
    # a colon, optional spaces, the number, and an optional trailing comment.
    pattern = re.compile(r'^(\s*"[^"]*"\s*:\s*)\d+(\s*(?:#.*)?)$')

    with open(input_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    out_lines = []
    for lineno, line in enumerate(lines, start=1):
        match = pattern.match(line)
        if match:
            out_lines.append(match.group(1) + str(lineno) + match.group(2))
        else:
            out_lines.append(line)

    if output_path and output_path != '-':
        with open(output_path, 'w', encoding='utf-8') as f:
            f.writelines(out_lines)
    else:
        sys.stdout.writelines(out_lines)


if __name__ == '__main__':
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print(f"Usage: {sys.argv[0]} <input.yml> [output.yml]", file=sys.stderr)
        sys.exit(1)
    renumber_yaml(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else None)
