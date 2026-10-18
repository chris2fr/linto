"""Manage and install shell aliases from launch/lib/aliases.yml."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
import yaml


def detect_current_shell() -> str:
    # Check SHELL environment variable first
    shell_env = os.environ.get("SHELL", "")
    if shell_env:
        name = Path(shell_env).name
        if name in {"fish", "zsh", "bash", "sh", "ksh"}:
            return name

    # Fallback to parent process or default
    try:
        import psutil
        parent_name = Path(psutil.Process(os.getppid()).name()).name
        if parent_name in {"fish", "zsh", "bash", "sh", "ksh"}:
            return parent_name
    except Exception:
        pass

    return "sh"


def main() -> int:
    parser = argparse.ArgumentParser(description="Install Linto shell aliases.")
    parser.add_argument(
        "-s", "--shell",
        choices=["fish", "zsh", "bash", "sh", "ksh"],
        default=detect_current_shell(),
        help="Target shell to update aliases for (defaults to current shell)"
    )
    args = parser.parse_args()
    target_shell = args.shell

    script_dir = Path(__file__).resolve().parent
    aliases_file = script_dir / "aliases.yml"
    
    try:
        data = yaml.safe_load(aliases_file.read_text())
    except Exception as exc:
        print(f"error: failed to read aliases.yml: {exc}", file=sys.stderr)
        return 1

    if not isinstance(data, dict):
        print("error: aliases.yml must contain a YAML mapping", file=sys.stderr)
        return 1

    aliases = data.get("aliases", {})
    unaliases = data.get("unaliases", [])
    if not isinstance(aliases, dict) or any(
        not isinstance(name, str) or not isinstance(command, str)
        for name, command in aliases.items()
    ):
        print("error: 'aliases' in aliases.yml must be a mapping of names to command strings", file=sys.stderr)
        return 1
    if not isinstance(unaliases, list) or any(not isinstance(name, str) for name in unaliases):
        print("error: 'unaliases' in aliases.yml must be a list of alias names", file=sys.stderr)
        return 1

    if not aliases and not unaliases:
        print("No aliases or unaliases defined in aliases.yml")
        return 0

    home = Path.home()

    if target_shell == "fish":
        update_fish_aliases(aliases, unaliases)
        print("Aliases updated successfully for fish.")
    elif target_shell == "zsh":
        update_sh_aliases(home / ".zshrc", aliases, unaliases)
        print("Aliases updated successfully for zsh (~/.zshrc).")
    elif target_shell == "bash":
        update_sh_aliases(home / ".bashrc", aliases, unaliases)
        print("Aliases updated successfully for bash (~/.bashrc).")
    elif target_shell == "sh":
        update_sh_aliases(home / ".profile", aliases, unaliases)
        print("Aliases updated successfully for sh (~/.profile).")
    elif target_shell == "ksh":
        update_sh_aliases(home / ".kshrc", aliases, unaliases)
        print("Aliases updated successfully for ksh (~/.kshrc).")
    else:
        print(f"error: unsupported shell: {target_shell}", file=sys.stderr)
        return 1

    return 0


def update_sh_aliases(rc_path: Path, aliases: dict[str, str], unaliases: list[str]) -> None:
    begin_marker = "# >>> linto aliases begin >>>"
    end_marker = "# >>> linto aliases end >>>"

    lines = []
    if rc_path.is_file():
        lines = rc_path.read_text().splitlines()

    # Filter out existing linto alias block
    new_lines = []
    skip = False
    for line in lines:
        if line.strip() == begin_marker:
            skip = True
            continue
        if line.strip() == end_marker:
            skip = False
            continue
        if not skip:
            new_lines.append(line)

    # Filter out unaliases if they happen to exist elsewhere in the file (optional, but good practice)
    # Or specifically within our block. Here we build the block with only valid active aliases.
    active_aliases = {k: v for k, v in aliases.items() if k not in unaliases}

    if active_aliases:
        # Build new block
        block = [begin_marker]
        for name, cmd in active_aliases.items():
            block.append(f"alias {name}='{cmd}'")
        block.append(end_marker)

        # Append block
        if new_lines and new_lines[-1].strip() != "":
            new_lines.append("")
        new_lines.extend(block)

    rc_path.write_text("\n".join(new_lines) + "\n")


def update_fish_aliases(aliases: dict[str, str], unaliases: list[str]) -> None:
    if not any(Path(p).exists() for p in ["/usr/bin/fish", "/usr/local/bin/fish", "/bin/fish"]) and not subprocess.run(["which", "fish"], capture_output=True).returncode == 0:
        print("warning: fish shell not found on system", file=sys.stderr)
        return

    # Add/update aliases
    for name, cmd in aliases.items():
        if name in unaliases:
            continue
        try:
            subprocess.run(["fish", "-c", f"alias --save {name} '{cmd}'"], capture_output=True, check=True)
        except Exception as exc:
            print(f"error saving fish alias {name}: {exc}", file=sys.stderr)

    # Remove unaliases using erase
    for name in unaliases:
        try:
            # functions -e erases a function/alias in fish
            subprocess.run(["fish", "-c", f"functions -e {name}; and erase {name} 2>/dev/null; true"], capture_output=True, check=True)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
