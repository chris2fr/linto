#!/usr/bin/env python3
"""Read and update Linto's groups configuration."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml


def load(path: Path) -> dict:
    try:
        data = yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"cannot read configuration {path}: {exc}") from exc
    if not isinstance(data, dict) or not isinstance(data.get("groups"), dict):
        raise ValueError("config must contain a 'groups' mapping")
    for name, options in data["groups"].items():
        if not isinstance(name, str) or not name or not all(c.isalnum() or c in "_-" for c in name):
            raise ValueError(f"invalid group name: {name!r}")
        if options == "default":
            continue
        if not isinstance(options, dict):
            raise ValueError(f"group {name!r} must be 'default' or a mapping")
        unknown = set(options) - {"enable", "short-stubs"}
        if unknown:
            raise ValueError(f"unknown option(s) for group {name!r}: {', '.join(sorted(unknown))}")
        if "enable" in options and not isinstance(options["enable"], bool):
            raise ValueError(f"group {name!r}: enable must be true or false")
        if "short-stubs" in options and not isinstance(options["short-stubs"], bool):
            raise ValueError(f"group {name!r}: short-stubs must be true or false")
    return data


def enabled_groups(data: dict, root: Path) -> list[str]:
    result = []
    for name, options in data["groups"].items():
        enabled = True if options == "default" else options.get("enable", True)
        if enabled and (root / name).is_dir():
            result.append(name)
    return result


def group_options(data: dict, name: str) -> dict:
    value = data["groups"].get(name, "default")
    return {"enable": True, "short-stubs": True} if value == "default" else {
        "enable": value.get("enable", True),
        "short-stubs": value.get("short-stubs", True),
    }


def dump(data: dict, path: Path) -> None:
    text = yaml.safe_dump(data, sort_keys=False, allow_unicode=True, default_flow_style=False)
    path.write_text(text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("list")
    options_parser = sub.add_parser("options")
    options_parser.add_argument("group")
    add_parser = sub.add_parser("add")
    add_parser.add_argument("group")
    rm_parser = sub.add_parser("remove")
    rm_parser.add_argument("group")
    args = parser.parse_args()

    try:
        data = load(args.config)
        if args.action == "list":
            for group in enabled_groups(data, args.config.parent):
                print(group)
        elif args.action == "options":
            options = group_options(data, args.group)
            print("true" if options["enable"] else "false")
            print("true" if options["short-stubs"] else "false")
        elif args.action == "add":
            current = data["groups"].get(args.group)
            if current == "default":
                data["groups"][args.group] = {"enable": True}
            elif isinstance(current, dict):
                current["enable"] = True
            else:
                data["groups"][args.group] = "default"
            dump(data, args.config)
        elif args.action == "remove":
            current = data["groups"].get(args.group)
            if current == "default":
                del data["groups"][args.group]
            elif isinstance(current, dict):
                current["enable"] = False
            else:
                raise ValueError(f"group {args.group!r} is not configured")
            dump(data, args.config)
    except ValueError as exc:
        print(f"config: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
