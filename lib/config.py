#!/usr/bin/env python3
"""Read and update Linto's groups configuration."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml


def load_defaults() -> dict:
    defaults_path = Path(__file__).with_name("defaults.yml")
    try:
        defaults = yaml.safe_load(defaults_path.read_text())
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"cannot read defaults {defaults_path}: {exc}") from exc
    if not isinstance(defaults, dict) or not isinstance(defaults.get("groups"), dict):
        raise ValueError("defaults.yml must contain a 'groups' mapping")
    alias_defaults_path = defaults_path.parent.parent / "linto" / "lib" / "aliases.yml"
    if alias_defaults_path.is_file():
        try:
            alias_defaults = yaml.safe_load(alias_defaults_path.read_text())
        except (OSError, yaml.YAMLError) as exc:
            raise ValueError(f"cannot read alias defaults {alias_defaults_path}: {exc}") from exc
        validate_shell_aliases(alias_defaults, "linto/lib/aliases.yml")
        defaults["groups"].setdefault("linto", {})["aliases"] = alias_defaults
    else:
        defaults["groups"].setdefault("linto", {}).setdefault(
            "aliases", {"aliases": {}, "unaliases": []}
        )
    for name, options in defaults["groups"].items():
        if not isinstance(name, str) or not isinstance(options, dict):
            raise ValueError("defaults.yml group entries must be mappings")
    quarto = defaults["groups"].get("quarto", {})
    if "extension" in quarto and (
        not isinstance(quarto["extension"], str) or not quarto["extension"].strip()
    ):
        raise ValueError("defaults.yml groups.quarto.extension must be a non-empty string")
    linto = defaults["groups"].get("linto", {})
    if "aliases" in linto:
        validate_shell_aliases(linto["aliases"], "defaults.yml groups.linto.aliases")
    return defaults


def validate_shell_aliases(value: object, label: str) -> None:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a mapping")
    unknown = set(value) - {"aliases", "unaliases"}
    if unknown:
        raise ValueError(f"{label} has unknown option(s): {', '.join(sorted(unknown))}")
    aliases = value.get("aliases", {})
    unaliases = value.get("unaliases", [])
    if not isinstance(aliases, dict) or any(
        not isinstance(name, str) or not name or not isinstance(command, str)
        for name, command in aliases.items()
    ):
        raise ValueError(f"{label}.aliases must map alias names to command strings")
    if not isinstance(unaliases, list) or any(not isinstance(name, str) for name in unaliases):
        raise ValueError(f"{label}.unaliases must be a list of alias names")


def load(path: Path) -> dict:
    try:
        data = yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"cannot read configuration {path}: {exc}") from exc
    if not isinstance(data, dict) or not isinstance(data.get("groups"), dict):
        raise ValueError("config must contain a 'groups' mapping")
    if "quarto" in data:
        raise ValueError("move Quarto settings to groups.quarto")
    default_groups = load_defaults()["groups"]
    for name, options in data["groups"].items():
        if not isinstance(name, str) or not name or not all(c.isalnum() or c in "_-" for c in name):
            raise ValueError(f"invalid group name: {name!r}")
        if options == "default":
            continue
        if not isinstance(options, dict):
            raise ValueError(f"group {name!r} must be 'default' or a mapping")
        allowed_options = {"enable", *default_groups.get(name, {}).keys()}
        unknown = set(options) - allowed_options
        if unknown:
            raise ValueError(f"unknown option(s) for group {name!r}: {', '.join(sorted(unknown))}")
        if "enable" in options and not isinstance(options["enable"], bool):
            raise ValueError(f"group {name!r}: enable must be true or false")
        if name == "quarto" and "extension" in options:
            extension = options["extension"]
            if not isinstance(extension, str) or not extension.strip():
                raise ValueError("groups.quarto.extension must be a non-empty string")
        if name == "linto" and "aliases" in options:
            validate_shell_aliases(options["aliases"], "groups.linto.aliases")

    aliases = data.get("shortcuts", {})
    if not isinstance(aliases, dict):
        raise ValueError("'shortcuts' must be a mapping of alias names to 'GROUP COMMAND' targets")
    for alias, target in aliases.items():
        if not isinstance(alias, str) or not alias or not all(
            char.isalnum() or char in "_-" for char in alias
        ):
            raise ValueError(f"invalid shortcut alias name: {alias!r}")
        if alias in {"help", "completion"} or alias in data["groups"]:
            raise ValueError(f"shortcut alias name is reserved: {alias!r}")
        if not isinstance(target, str):
            raise ValueError(f"shortcuts.{alias} must be a 'GROUP COMMAND' string")
        parts = target.split()
        if len(parts) != 2 or not all(
            part and all(char.isalnum() or char in "_-" for char in part)
            for part in parts
        ):
            raise ValueError(f"shortcuts.{alias} must be a 'GROUP COMMAND' string")
        if parts[0] not in data["groups"]:
            raise ValueError(f"shortcuts.{alias} references unknown group {parts[0]!r}")
    return data


def enabled_groups(data: dict, root: Path) -> list[str]:
    result = []
    reserved = {"bin", "completions", "man", "old", "tests", "lib"}
    for name, options in data["groups"].items():
        enabled = True if options == "default" else options.get("enable", True)
        if name not in reserved and enabled and (root / name).is_dir():
            result.append(name)
    return result


def group_options(data: dict, name: str) -> dict:
    value = data["groups"].get(name, "default")
    options = dict(load_defaults()["groups"].get(name, {}))
    if value != "default":
        for key, item in value.items():
            if key == "aliases" and isinstance(options.get(key), dict) and isinstance(item, dict):
                merged = dict(options[key])
                if "aliases" in item:
                    merged_aliases = dict(merged.get("aliases", {}))
                    merged_aliases.update(item["aliases"])
                    merged["aliases"] = merged_aliases
                if "unaliases" in item:
                    merged["unaliases"] = item["unaliases"]
                options[key] = merged
            else:
                options[key] = item
    options.setdefault("enable", True)
    return options


def markdown_viewers(data: dict) -> list[str]:
    """Return configured Markdown viewers in preference order."""
    viewers = data.get("markdown-viewer", ["cat"])
    if isinstance(viewers, str):
        viewers = [viewers]
    if not isinstance(viewers, list) or not viewers:
        raise ValueError("'markdown-viewer' must be a non-empty string or list")
    result = []
    for viewer in viewers:
        if not isinstance(viewer, str) or not viewer.strip():
            raise ValueError("'markdown-viewer' entries must be non-empty strings")
        result.append(viewer.strip())
    return result


def quarto_extension(data: dict) -> str:
    """Return the configured Quarto extension repository."""
    extension = group_options(data, "quarto").get("extension", "chris2fr/quarto")
    if not isinstance(extension, str) or not extension.strip():
        raise ValueError("groups.quarto.extension must be a non-empty string")
    return extension.strip()


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
    sub.add_parser("aliases")
    sub.add_parser("quarto-extension")
    sub.add_parser("markdown-viewer")
    sub.add_parser("version")
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
        elif args.action == "aliases":
            for alias, target in data.get("shortcuts", {}).items():
                group, command = target.split()
                print(f"{alias}\t{group}\t{command}")
        elif args.action == "quarto-extension":
            print(quarto_extension(data))
        elif args.action == "markdown-viewer":
            for viewer in markdown_viewers(data):
                print(viewer)
        elif args.action == "version":
            version = data.get("version")
            if not isinstance(version, str) or not version.strip():
                raise ValueError("'version' must be a non-empty string")
            print(version.strip())
        elif args.action == "add":
            current = data["groups"].get(args.group)
            if current == "default":
                pass
            elif isinstance(current, dict):
                current["enable"] = True
            else:
                data["groups"][args.group] = "default"
            dump(data, args.config)
        elif args.action == "remove":
            current = data["groups"].get(args.group)
            if current == "default":
                del data["groups"][args.group]
                for alias, target in list(data.get("shortcuts", {}).items()):
                    if target.split()[0] == args.group:
                        del data["shortcuts"][alias]
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
