#!/usr/bin/env python3
"""Read and update Linto's command and configdata configuration."""

from __future__ import annotations

import argparse
import os
import sys
from collections.abc import Iterable
from pathlib import Path

import yaml


NAME_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")


def read_yaml_mapping(path: Path, label: str) -> dict:
    try:
        value = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"cannot read {label} {path}: {exc}") from exc
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise ValueError(f"{label} {path} must contain a mapping")
    return value


def merge_mappings(base: dict, override: dict) -> dict:
    """Deep-merge mappings; values other than mappings are replaced."""
    result = dict(base)
    for key, value in override.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = merge_mappings(result[key], value)
        else:
            result[key] = value
    return result


def read_default_configdata(path: Path, label: str) -> dict:
    defaults = read_yaml_mapping(path, label)
    unknown = set(defaults) - {"configdata"}
    if unknown:
        raise ValueError(f"{label} {path} only accepts a 'configdata' mapping")
    configdata = defaults.get("configdata", {})
    validate_configdata(configdata, f"{label} configdata")
    return configdata


def xdg_directory(variable: str, fallback: Path) -> Path:
    value = os.environ.get(variable)
    candidate = Path(value) if value else fallback
    return candidate if candidate.is_absolute() else fallback


def config_directory() -> Path:
    return xdg_directory("XDG_CONFIG_HOME", Path.home() / ".config") / "linto"


def data_directory() -> Path:
    return xdg_directory("XDG_DATA_HOME", Path.home() / ".local" / "share") / "linto"


def user_config_file() -> Path:
    return config_directory() / "config.yml"


def user_groups_directory() -> Path:
    return data_directory() / "groups"


def load_defaults(root: Path, data_root: Path | None = None) -> dict:
    root_defaults_path = root / "lib" / "default.yml"
    root_configdata = read_default_configdata(root_defaults_path, "root defaults")
    groups = {}
    group_roots = [root / "groups"]
    if data_root is not None:
        group_roots.append(data_root / "groups")
    for group_root in group_roots:
        for group_defaults_path in group_root.glob("*/lib/default.yml"):
            group_name = group_defaults_path.parent.parent.name
            group_configdata = read_default_configdata(group_defaults_path, "group defaults")
            groups[group_name] = merge_mappings(groups.get(group_name, {}), group_configdata)
    return {"configdata": root_configdata, "groups": groups}


def valid_name(value: object) -> bool:
    return isinstance(value, str) and bool(value) and all(char in NAME_CHARS for char in value)


def validate_configdata(value: object, label: str) -> None:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a mapping")


def validate_aliases(value: object, label: str) -> None:
    if not isinstance(value, dict) or any(
        not valid_name(name) or not isinstance(command, str)
        for name, command in value.items()
    ):
        raise ValueError(f"{label} must map alias names to command strings")


def validate(data: dict, defaults: dict) -> dict:
    if not isinstance(data.get("groups"), dict):
        raise ValueError("config must contain a 'groups' mapping")
    if "quarto" in data:
        raise ValueError("move Quarto settings to groups.quarto.configdata")
    if "markdown-viewer" in data:
        raise ValueError("move 'markdown-viewer' to configdata.markdown-viewer")

    unknown_root = set(data) - {"version", "groups", "shortcuts", "configdata"}
    if unknown_root:
        raise ValueError(f"unknown top-level configuration key(s): {', '.join(sorted(unknown_root))}")
    validate_configdata(data.get("configdata", {}), "configdata")

    for group_name, group in data["groups"].items():
        if not valid_name(group_name):
            raise ValueError(f"invalid group name: {group_name!r}")
        if group == "default":
            continue
        if not isinstance(group, dict):
            raise ValueError(f"group {group_name!r} must be 'default' or a mapping")
        unknown_options = set(group) - {"enable", "configdata", "commands"}
        if unknown_options:
            raise ValueError(
                f"unknown option(s) for group {group_name!r}: "
                f"{', '.join(sorted(unknown_options))}"
            )
        if "enable" in group and not isinstance(group["enable"], bool):
            raise ValueError(f"group {group_name!r}: enable must be true or false")
        if "configdata" in group:
            validate_configdata(group["configdata"], f"groups.{group_name}.configdata")
        commands = group.get("commands", {})
        if not isinstance(commands, dict):
            raise ValueError(f"groups.{group_name}.commands must be a mapping")
        for command_name, command in commands.items():
            if not valid_name(command_name):
                raise ValueError(f"invalid command name in group {group_name!r}: {command_name!r}")
            if not isinstance(command, dict):
                raise ValueError(f"groups.{group_name}.commands.{command_name} must be a mapping")
            unknown_command_options = set(command) - {"enable", "configdata"}
            if unknown_command_options:
                raise ValueError(
                    f"unknown option(s) for command {group_name} {command_name}: "
                    f"{', '.join(sorted(unknown_command_options))}"
                )
            if "enable" in command and not isinstance(command["enable"], bool):
                raise ValueError(
                    f"groups.{group_name}.commands.{command_name}.enable must be true or false"
                )
            if "configdata" in command:
                validate_configdata(
                    command["configdata"],
                    f"groups.{group_name}.commands.{command_name}.configdata",
                )

    shortcuts = data.get("shortcuts", {})
    if not isinstance(shortcuts, dict):
        raise ValueError("'shortcuts' must be a mapping of alias names to 'GROUP COMMAND' targets")
    for alias, target in shortcuts.items():
        if not valid_name(alias):
            raise ValueError(f"invalid shortcut alias name: {alias!r}")
        if alias in {"help", "completion"} or alias in data["groups"]:
            raise ValueError(f"shortcut alias name is reserved: {alias!r}")
        if not isinstance(target, str):
            raise ValueError(f"shortcuts.{alias} must be a 'GROUP COMMAND' string")
        parts = target.split()
        if len(parts) != 2 or not all(valid_name(part) for part in parts):
            raise ValueError(f"shortcuts.{alias} must be a 'GROUP COMMAND' string")
        if parts[0] not in data["groups"]:
            raise ValueError(f"shortcuts.{alias} references unknown group {parts[0]!r}")

    # Validate effective configdata for the settings with a known schema.
    root_configdata = merge_mappings(defaults["configdata"], data.get("configdata", {}))
    if "markdown-viewer" in root_configdata:
        validate_markdown_viewers(root_configdata["markdown-viewer"])
    for group_name, group_defaults in defaults["groups"].items():
        if not isinstance(group_defaults, dict):
            raise ValueError(f"defaults for group {group_name!r} must be a mapping")
        if group_name == "linto" and "aliases" in group_defaults:
            validate_aliases(group_defaults["aliases"], "groups/linto/lib/default.yml configdata.aliases")
        if group_name == "quarto" and "extension" in group_defaults:
            extension = group_defaults["extension"]
            if not isinstance(extension, str) or not extension.strip():
                raise ValueError("groups/quarto/lib/default.yml extension must be a non-empty string")
    for group_name in data["groups"]:
        group_configdata = merge_mappings(
            defaults["groups"].get(group_name, {}),
            data["groups"][group_name].get("configdata", {})
            if isinstance(data["groups"][group_name], dict)
            else {},
        )
        if group_name == "linto" and "aliases" in group_configdata:
            validate_aliases(group_configdata["aliases"], "groups.linto.configdata.aliases")
        if group_name == "quarto" and "extension" in group_configdata:
            extension = group_configdata["extension"]
            if not isinstance(extension, str) or not extension.strip():
                raise ValueError("groups.quarto.configdata.extension must be a non-empty string")
    return data


def config_overlays(home: Path | None = None) -> list[Path]:
    """Return system and user configuration paths, in increasing precedence."""
    home = home or Path.home()
    config_home = xdg_directory("XDG_CONFIG_HOME", home / ".config")
    return [
        Path("/etc/linto/linto.yml"),
        home / ".linto.yml",
        config_home / "linto" / "config.yml",
    ]


def load(
    path: Path,
    defaults_root: Path | None = None,
    data_root: Path | None = None,
    overlays: Iterable[Path] = (),
) -> dict:
    try:
        data = read_yaml_mapping(path, "configuration")
        for overlay_path in overlays:
            if overlay_path.is_file():
                data = merge_mappings(data, read_yaml_mapping(overlay_path, "configuration overlay"))
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"cannot read configuration {path}: {exc}") from exc
    root = defaults_root or path.parent
    user_data = data_root or data_directory()
    defaults = load_defaults(root, user_data)
    validate(data, defaults)
    data["_defaults"] = defaults
    data["_root"] = root
    data["_data_root"] = user_data
    return data


def defaults_for(data: dict) -> dict:
    defaults = data.get("_defaults")
    if defaults is None:
        defaults = load_defaults(
            Path(data.get("_root", Path.cwd())),
            Path(data.get("_data_root", data_directory())),
        )
    return defaults


def group_options(data: dict, name: str) -> dict:
    group = data["groups"].get(name, "default")
    defaults = defaults_for(data)["groups"].get(name, {})
    configdata = merge_mappings(defaults, group.get("configdata", {}) if isinstance(group, dict) else {})
    return {
        "enable": True if group == "default" else group.get("enable", True),
        "configdata": configdata,
        "commands": group.get("commands", {}) if isinstance(group, dict) else {},
    }


def command_configdata(data: dict, group_name: str, command_name: str) -> dict:
    group = data["groups"].get(group_name, "default")
    group_commands = group.get("commands", {}) if isinstance(group, dict) else {}
    command = group_commands.get(command_name, {})
    root = Path(data.get("_root", Path.cwd()))
    data_root = Path(data.get("_data_root", data_directory()))
    command_defaults = {}
    for command_defaults_path in (
        root / "groups" / group_name / "lib" / f"{command_name}.yml",
        data_root / "groups" / group_name / "lib" / f"{command_name}.yml",
    ):
        if command_defaults_path.is_file():
            command_defaults = merge_mappings(
                command_defaults,
                read_default_configdata(command_defaults_path, "command defaults"),
            )
    return merge_mappings(
        command_defaults,
        command.get("configdata", {}) if isinstance(command, dict) else {},
    )


def command_options(data: dict, group_name: str, command_name: str) -> dict:
    options = group_options(data, group_name)
    group = data["groups"].get(group_name, "default")
    group_commands = group.get("commands", {}) if isinstance(group, dict) else {}
    command = group_commands.get(command_name, {})
    return {
        "enable": command.get("enable", True) if isinstance(command, dict) else True,
        "configdata": merge_mappings(
            options["configdata"], command_configdata(data, group_name, command_name)
        ),
    }


def configdata(data: dict, group: str | None = None, command: str | None = None) -> dict:
    defaults = defaults_for(data)
    root_data = merge_mappings(
        defaults["configdata"], data.get("configdata", {})
    )
    if group is None:
        if command is not None:
            raise ValueError("a group is required when requesting command configdata")
        return root_data
    group_data = command_options(data, group, command)["configdata"] if command else group_options(data, group)["configdata"]
    return merge_mappings(root_data, group_data)


def enabled_groups(data: dict, root: Path, data_root: Path | None = None) -> list[str]:
    result = []
    reserved = {"bin", "completions", "man", "tests", "lib"}
    user_groups = (data_root or Path(data.get("_data_root", data_directory()))) / "groups"
    for name in data["groups"]:
        enabled = group_options(data, name)["enable"]
        exists = (root / "groups" / name).is_dir() or (user_groups / name).is_dir()
        if name not in reserved and enabled and exists:
            result.append(name)
    return result


def effective_config(data: dict) -> dict:
    """Return a read-only view of configuration with defaults merged in."""
    result = {}
    if "version" in data:
        result["version"] = data["version"]
    result["groups"] = {}
    if "shortcuts" in data:
        result["shortcuts"] = data["shortcuts"]
    result["configdata"] = configdata(data)

    root = Path(data.get("_root", Path.cwd()))
    data_root = Path(data.get("_data_root", data_directory()))
    for group_name in data["groups"]:
        options = group_options(data, group_name)
        effective_group = {
            "enable": options["enable"],
            "configdata": options["configdata"],
        }
        group = data["groups"].get(group_name, "default")
        configured_commands = group.get("commands", {}) if isinstance(group, dict) else {}
        command_names = set(configured_commands)
        for command_lib in (
            root / "groups" / group_name / "lib",
            data_root / "groups" / group_name / "lib",
        ):
            if command_lib.is_dir():
                command_names.update(
                    path.stem for path in command_lib.glob("*.yml")
                    if path.stem != "default" and valid_name(path.stem)
                )
        if command_names:
            effective_group["commands"] = {}
            for command_name in sorted(command_names):
                command = configured_commands.get(command_name, {})
                effective_group["commands"][command_name] = {
                    "enable": command.get("enable", True) if isinstance(command, dict) else True,
                    "configdata": command_configdata(data, group_name, command_name),
                }
        result["groups"][group_name] = effective_group
    return result


def validate_markdown_viewers(viewers: object) -> list[str]:
    if isinstance(viewers, str):
        viewers = [viewers]
    if not isinstance(viewers, list) or not viewers:
        raise ValueError("'configdata.markdown-viewer' must be a non-empty string or list")
    result = []
    for viewer in viewers:
        if not isinstance(viewer, str) or not viewer.strip():
            raise ValueError("'configdata.markdown-viewer' entries must be non-empty strings")
        result.append(viewer.strip())
    return result


def markdown_viewers(data: dict) -> list[str]:
    """Return configured Markdown viewers in preference order."""
    viewers = configdata(data).get("markdown-viewer", ["cat"])
    return validate_markdown_viewers(viewers)


def quarto_extension(data: dict) -> str:
    """Return the configured Quarto extension repository."""
    extension = configdata(data, "quarto").get("extension", "chris2fr/quarto")
    if not isinstance(extension, str) or not extension.strip():
        raise ValueError("groups.quarto.configdata.extension must be a non-empty string")
    return extension.strip()


def set_user_group_enabled(group: str, enabled: bool) -> None:
    if not valid_name(group):
        raise ValueError(f"invalid group name: {group!r}")
    path = user_config_file()
    data = read_yaml_mapping(path, "user configuration") if path.is_file() else {}
    groups = data.setdefault("groups", {})
    if not isinstance(groups, dict):
        raise ValueError("user config 'groups' must be a mapping")
    current = groups.get(group)
    if enabled:
        if current == "default":
            pass
        elif isinstance(current, dict):
            current["enable"] = True
        else:
            groups[group] = "default"
    elif isinstance(current, dict):
        current["enable"] = False
    else:
        groups[group] = {"enable": False}

    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    text = yaml.safe_dump(data, sort_keys=False, allow_unicode=True, default_flow_style=False)
    temporary.write_text(text, encoding="utf-8")
    temporary.replace(path)



def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("list")
    options_parser = sub.add_parser("options")
    options_parser.add_argument("group")
    command_enabled_parser = sub.add_parser("command-enabled")
    command_enabled_parser.add_argument("group")
    command_enabled_parser.add_argument("command")
    sub.add_parser("disabled-commands")
    configdata_parser = sub.add_parser("configdata")
    configdata_parser.add_argument("group", nargs="?")
    configdata_parser.add_argument("command", nargs="?")
    sub.add_parser("effective")
    sub.add_parser("aliases")
    sub.add_parser("shell-state")
    sub.add_parser("quarto-extension")
    sub.add_parser("markdown-viewer")
    sub.add_parser("version")
    add_parser = sub.add_parser("add")
    add_parser.add_argument("group")
    rm_parser = sub.add_parser("remove")
    rm_parser.add_argument("group")
    args = parser.parse_args()

    try:
        installation_root = Path(__file__).resolve().parent.parent
        if args.action in {"add", "remove"}:
            set_user_group_enabled(args.group, args.action == "add")
            return 0
        user_data = data_directory()
        data = load(
            args.config,
            defaults_root=installation_root,
            data_root=user_data,
            overlays=config_overlays(),
        )
        if args.action == "list":
            for group in enabled_groups(data, installation_root, user_data):
                print(group)
        elif args.action == "options":
            print("true" if group_options(data, args.group)["enable"] else "false")
        elif args.action == "command-enabled":
            print("true" if command_options(data, args.group, args.command)["enable"] else "false")
        elif args.action == "disabled-commands":
            for group in data["groups"]:
                options = group_options(data, group)
                for command in options["commands"]:
                    if not command_options(data, group, command)["enable"]:
                        print(f"{group}/{command}")
        elif args.action == "configdata":
            if args.group is not None and args.group not in data["groups"]:
                raise ValueError(f"unknown group: {args.group}")
            result = configdata(data, args.group, args.command)
            print(yaml.safe_dump(result, sort_keys=False, allow_unicode=True), end="")
        elif args.action == "effective":
            print(yaml.safe_dump(effective_config(data), sort_keys=False, allow_unicode=True), end="")
        elif args.action == "aliases":
            for alias, target in data.get("shortcuts", {}).items():
                group, command = target.split()
                print(f"{alias}\t{group}\t{command}")
        elif args.action == "shell-state":
            for group in enabled_groups(data, installation_root, user_data):
                print(f"G\t{group}")
            for alias, target in data.get("shortcuts", {}).items():
                group, command = target.split()
                print(f"A\t{alias}\t{group}\t{command}")
            for group in data["groups"]:
                for command in group_options(data, group)["commands"]:
                    if not command_options(data, group, command)["enable"]:
                        print(f"D\t{group}/{command}")
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
    except (OSError, ValueError) as exc:
        print(f"config: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
