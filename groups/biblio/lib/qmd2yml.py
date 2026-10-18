#!/usr/bin/env python3
"""Extract citation keys from QMD and write numbered YAML or CSV."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

import yaml
from yaml.nodes import MappingNode, ScalarNode


CITATION_CLUSTER = re.compile(r"\[([^]]*@[^]]*)\]")
CITATION_KEY = re.compile(r"-?@([^\s,;\]]+)")
ELLIPSIS_KEYS = {"...", "…"}


def citation_keys(text: str, order_by: str) -> list[str]:
    keys: list[str] = []
    seen: set[str] = set()
    for cluster in CITATION_CLUSTER.finditer(text):
        for citation in CITATION_KEY.finditer(cluster.group(1)):
            key = citation.group(1)
            if key not in ELLIPSIS_KEYS and key not in seen:
                seen.add(key)
                keys.append(key)
    if order_by == "key":
        keys.sort()
    return keys


def read_seed(path: Path) -> tuple[bytes, list[tuple[str, int]]]:
    try:
        raw = path.read_bytes()
        text = raw.decode("utf-8")
        root = yaml.compose(text, Loader=yaml.SafeLoader)
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as exc:
        raise ValueError(f"cannot read valid UTF-8 YAML from '{path}': {exc}") from exc

    if root is None:
        raise ValueError(f"'{path}' must contain a YAML mapping of reference keys to numbers")
    if not isinstance(root, MappingNode):
        raise TypeError(f"'{path}' must contain a YAML mapping of reference keys to numbers")

    refs: list[tuple[str, int]] = []
    seen: set[str] = set()
    for key_node, value_node in root.value:
        if not isinstance(key_node, ScalarNode) or not isinstance(value_node, ScalarNode):
            raise TypeError(f"'{path}' must contain only scalar reference keys and numeric values")
        key = key_node.value
        if key in seen:
            raise ValueError(f"'{path}' contains duplicate reference key {key!r}")
        if not re.fullmatch(r"[0-9]+", value_node.value):
            raise ValueError(f"'{path}' has a non-numeric value for reference {key!r}")
        seen.add(key)
        refs.append((key, int(value_node.value)))

    raw_without_blank_lines = b"".join(
        line for line in raw.splitlines(keepends=True) if line.strip()
    )
    return raw_without_blank_lines, refs


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract unique Pandoc-style citation keys from a Quarto/Markdown file."
    )
    parser.add_argument("--order-by", choices=["appearance", "key"], default="appearance")
    parser.add_argument("--format", choices=["yml", "yaml", "csv"], default="yml")
    parser.add_argument("--start", type=int, default=1, help="First YAML number without --yml (default: 1).")
    parser.add_argument("-y", "--yml", type=Path, help="Existing numbered YAML mapping to preserve and extend.")
    parser.add_argument("file", type=Path, help="Input Quarto/Markdown file")
    args = parser.parse_args()

    if args.start < 0:
        parser.error("--start must be a non-negative integer")
    if not args.file.is_file():
        parser.error(f"'{args.file}' is not a file")
    try:
        source = args.file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"error: cannot read '{args.file}': {exc}", file=sys.stderr)
        return 1

    seed_bytes = b""
    seed_refs: list[tuple[str, int]] = []
    if args.yml is not None:
        if args.format == "csv":
            parser.error("--yml can only be used with YAML output")
        if not args.yml.is_file():
            parser.error(f"'{args.yml}' is not a file")
        try:
            seed_bytes, seed_refs = read_seed(args.yml)
        except (TypeError, ValueError) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1

    keys = citation_keys(source, args.order_by)
    existing = {key for key, _ in seed_refs}
    new_keys = [key for key in keys if key not in existing]

    if args.format == "csv":
        writer = csv.writer(sys.stdout, lineterminator="\n")
        writer.writerows((key,) for key in keys)
        return 0

    first_number = seed_refs[-1][1] + 1 if seed_refs else args.start
    additions = "".join(
        f"{json.dumps(key, ensure_ascii=False)}: {number}\n"
        for number, key in enumerate(new_keys, start=first_number)
    ).encode("utf-8")

    if seed_bytes:
        sys.stdout.buffer.write(seed_bytes)
        if additions and not seed_bytes.endswith((b"\n", b"\r")):
            sys.stdout.buffer.write(b"\n")
    sys.stdout.buffer.write(additions)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
