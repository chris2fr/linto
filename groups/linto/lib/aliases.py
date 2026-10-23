"""Manage shell aliases from groups.linto.configdata.aliases."""

from __future__ import annotations

import importlib.util
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "lib"))
from clibase import Parser, _, fail  # noqa: E402

SHELLS = ("fish", "bash", "sh", "ksh", "zsh")


def _process_info(pid: int) -> tuple[str, list[str], int] | None:
    proc = Path("/proc") / str(pid)
    try:
        name = (proc / "comm").read_text(encoding="utf-8").strip()
        argv = [part.decode(errors="replace") for part in (proc / "cmdline").read_bytes().split(b"\0") if part]
        status = (proc / "status").read_text(encoding="utf-8")
        parent = next(int(line.split()[1]) for line in status.splitlines() if line.startswith("PPid:"))
    except (OSError, StopIteration, ValueError):
        return None
    return Path(name).name, argv, parent


def _is_shell_script_process(argv: list[str]) -> bool:
    for argument in argv[1:]:
        if argument.startswith("-"):
            continue
        candidate = Path(argument)
        try:
            if candidate.is_file():
                with candidate.open(encoding="utf-8", errors="ignore") as script:
                    return script.readline().startswith("#!")
        except OSError:
            continue
    return False


def _canonical_shell(name: str) -> str:
    name = Path(name).name.lstrip("-")
    if name in {"ksh93", "mksh"}:
        return "ksh"
    return name


def detect_current_shell() -> str:
    """Find the invoking shell, skipping shell processes running Linto scripts."""
    pid = os.getppid()
    visited = set()
    while pid > 1 and pid not in visited:
        visited.add(pid)
        info = _process_info(pid)
        if info is None:
            break
        name, argv, parent = info
        name = _canonical_shell(name)
        if name in SHELLS and not _is_shell_script_process(argv):
            return name
        pid = parent

    for variable, name in (
        ("FISH_VERSION", "fish"),
        ("ZSH_VERSION", "zsh"),
        ("KSH_VERSION", "ksh"),
        ("BASH_VERSION", "bash"),
    ):
        if os.environ.get(variable):
            return name
    shell_env = _canonical_shell(os.environ.get("SHELL", ""))
    return shell_env if shell_env in SHELLS else "sh"


def main() -> int:
    parser = Parser("linto", "aliases", description=_("Install Linto shell aliases."))
    parser.add_argument(
        "-s", "--shell", metavar="SHELL",
        choices=[*SHELLS, "all"],
        default=detect_current_shell(),
        help=_("Target shell (defaults to the invoking shell; 'all' updates fish, bash, sh, ksh, and zsh)"),
    )
    args = parser.parse_args()
    target_shells = SHELLS if args.shell == "all" else (args.shell,)

    repo_root = Path(__file__).resolve().parents[3]
    config_path = repo_root / "lib" / "config.py"
    spec = importlib.util.spec_from_file_location("linto_config", config_path)
    if spec is None or spec.loader is None:
        return fail("aliases", _("could not load the Linto config helper"))
    linto_config = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(linto_config)

    try:
        data = linto_config.load(
            repo_root / "config.yml",
            defaults_root=repo_root,
            overlays=linto_config.config_overlays(),
        )
        aliases = linto_config.configdata(data, "linto").get("aliases", {})
    except (OSError, ValueError) as exc:
        return fail("aliases", _("failed to read Linto configuration: {}").format(exc))

    if not isinstance(aliases, dict) or any(
        not isinstance(name, str) or not isinstance(command, str)
        for name, command in aliases.items()
    ):
        return fail("aliases", _("groups.linto.configdata.aliases must map names to command strings"))

    home = Path.home()
    errors = []
    for target_shell in target_shells:
        try:
            if target_shell == "fish":
                update_fish_aliases(aliases)
                destination = "Fish functions"
            elif target_shell == "zsh":
                zdotdir = Path(os.environ.get("ZDOTDIR", str(home)))
                if not zdotdir.is_absolute():
                    zdotdir = home
                aliases_file = linto_config.xdg_directory("XDG_CONFIG_HOME", home / ".config") / "zsh" / "aliases.zsh"
                update_zsh_aliases(zdotdir / ".zshrc", aliases_file, aliases)
                destination = f"{aliases_file} ({_('sourced from')} {zdotdir / '.zshrc'})"
            elif target_shell == "bash":
                update_sh_aliases(home / ".bashrc", aliases)
                destination = str(home / ".bashrc")
            elif target_shell == "sh":
                update_sh_aliases(home / ".profile", aliases)
                destination = str(home / ".profile")
            else:
                update_sh_aliases(home / ".kshrc", aliases)
                update_ksh_profile(home / ".profile")
                destination = f"{home / '.kshrc'} (ENV set in .profile)"
            print(_("Aliases updated for {}: {}").format(target_shell, destination))
        except (OSError, RuntimeError) as exc:
            errors.append(f"{target_shell}: {exc}")

    if errors:
        for error in errors:
            fail("aliases", _("error updating aliases for {}").format(error))
        return 1
    return 0


def _replace_managed_block(
    path: Path, begin_marker: str, end_marker: str, block: list[str]
) -> None:
    lines = path.read_text(encoding="utf-8").splitlines() if path.is_file() else []
    kept = []
    skipping = False
    for line in lines:
        if line.strip() == begin_marker:
            skipping = True
            continue
        if line.strip() == end_marker:
            skipping = False
            continue
        if not skipping:
            kept.append(line)
    if block:
        if kept and kept[-1].strip():
            kept.append("")
        kept.extend([begin_marker, *block, end_marker])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(kept) + "\n", encoding="utf-8")


def _shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def update_sh_aliases(rc_path: Path, aliases: dict[str, str]) -> None:
    block = [f"alias {name}={_shell_quote(command)}" for name, command in aliases.items()]
    _replace_managed_block(
        rc_path,
        "# >>> linto aliases begin >>>",
        "# >>> linto aliases end >>>",
        block,
    )


ZSH_ALIASES_BLOCK = [
    'mkdir -p -m 0700 "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/"',
    'touch "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/aliases.zsh"',
    'chmod 0600 "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/aliases.zsh"',
    'source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/aliases.zsh"',
]


def update_zsh_aliases(zshrc: Path, aliases_file: Path, aliases: dict[str, str]) -> None:
    """Keep the aliases in a file of their own, sourced from .zshrc.

    .zshrc gets a four-line managed block (create the directory 0700 and the file 0600 if
    needed, then source it); the same steps are done here, and the file itself is
    written entirely by Linto.
    """
    _replace_managed_block(
        zshrc, "# >>> linto aliases begin >>>", "# >>> linto aliases end >>>", ZSH_ALIASES_BLOCK
    )
    directory = aliases_file.parent
    if not directory.exists():
        directory.mkdir(parents=True)
        directory.chmod(0o700)
    lines = ["# Managed by `linto linto aliases`: changes made here are overwritten."]
    lines += [f"alias {name}={_shell_quote(command)}" for name, command in aliases.items()]
    temporary = aliases_file.with_name(aliases_file.name + ".tmp")
    temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    temporary.chmod(0o600)
    temporary.replace(aliases_file)


def update_ksh_profile(profile: Path) -> None:
    block = [
        'if [ -z "${ENV:-}" ]; then',
        '  ENV="$HOME/.kshrc"',
        "  export ENV",
        "fi",
    ]
    _replace_managed_block(
        profile,
        "# >>> linto ksh ENV begin >>>",
        "# >>> linto ksh ENV end >>>",
        block,
    )


def _fish_quote(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def update_fish_aliases(aliases: dict[str, str]) -> None:
    if shutil.which("fish") is None:
        raise RuntimeError(_("fish executable was not found on PATH"))
    for name, command in aliases.items():
        fish_command = f"alias --save {name} {_fish_quote(command)}"
        result = subprocess.run(
            ["fish", "-c", fish_command], capture_output=True, text=True, check=False
        )
        if result.returncode:
            detail = result.stderr.strip() or result.stdout.strip()
            raise RuntimeError(_("could not save alias {}: {}").format(name, detail))


if __name__ == "__main__":
    sys.exit(main())
