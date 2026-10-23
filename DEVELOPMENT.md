# Development

Notes for working in a Linto git checkout. These are not part of the Nix
package or the user guide.

## Group management scripts

`addgroup` and `rmgroup` edit the checkout's own `config.yml`, so they only make
sense on a mutable source tree. They are removed from the Nix package, whose
store tree is read-only. Installed systems enable or disable groups through the
`groups` mapping in `~/.config/linto/config.yml` or `programs.linto.settings`.

- `linto linto addgroup DIRECTORY` registers or re-enables a group.
- `linto linto rmgroup GROUP` removes a `default` entry or disables a mapped
  group.

Neither command deletes an existing group directory.

## Python environment

`linto linto venv` creates `$LINTO_ROOT/.venv` (`python3 -m venv`) and installs
`requirements.txt` into it; run it again after changing the requirements, or
with `--recreate` to rebuild. When `.venv/bin/python3` exists, the `linto`
dispatcher exports `LINTO_ROOT` and `VIRTUAL_ENV` and puts `.venv/bin` first on
`PATH`, so every command and every `#!/usr/bin/env python3` script runs with it.
`LINTO_NO_VENV=1` skips it for one run. `.venv` is git-ignored. The Nix package
provides its own Python with the same packages and does not ship `venv`.

## Python environment and optional packages

`requirements.txt` lists the packages every command may need (PyYAML,
bibtexparser, segno): about 18 MB, or 5 MB without pip. `linto linto install` creates
`$LINTO_ROOT/.venv` from it in the installed copy (`--no-venv` skips it) and keeps
it across upgrades. Larger optional packages are *extras*: one file
`requirements/NAME.txt` each, whose first lines say `# download: about N MB`.
`lib/extras.py` installs one on first use: `extras.ensure("cv2", "qr-opencv", "What
needs it", "prog")` returns true when the module imports, otherwise explains how to
install it (`linto linto venv --extra NAME`), or, on a terminal and with a writable
environment, asks and runs pip. `linto linto venv --all` installs every extra in
advance. The Nix package provides its own Python with the same packages.

## Backends

A command that can use several tools offers them as backends, tried in the order of
a list in `groups/GROUP/lib/default.yml` that users can reorder in
`groups.GROUP.configdata`. `linto utils qrdecode` has `zbar` (the `zbarimg` command,
package `zbar-tools`: small, no Python packages) and `opencv` (Python, extra
`qr-opencv`): `groups.utils.configdata.qrdecode.backends: [zbar]` by default (add `opencv` to the
list for a fallback), or `--backend NAME`. `--backend opencv`, or `opencv` in the list
when no backend is present, offers to install the `opencv` extra.

## Configuration templates

`etc/config.yml` holds the neutral installation defaults (enabled groups and standard
shortcuts) that `linto linto install --system` installs as the tree's `config.yml`;
`etc/linto.yml` is the commented template for `/etc/linto/linto.yml` and
`~/.linto.yml`. A checkout's own `config.yml` may hold personal settings and is
never copied by `--system`.

## Build and man pages

`linto linto build` regenerates command wrappers, Fish completions, the
active-group list in the dispatcher man page, and one man page per
`linto-guide/*.md` topic. Output goes to `${XDG_DATA_HOME:-~/.local/share}/linto`,
never into the checkout. It requires `mandown` and `groff`
(`linto linto mdsetup`); without them the guide man pages are skipped with a
warning. `linto linto addman` runs build and links the generated man page into
the user's man path. `addgroup` and `rmgroup` also run build. `linto linto install`
copies the tree to a prefix and builds from the copy (so the generated wrappers
point at the installed tree), then configures the shells (`--user`, prefix
`~/.local`) or links commands and completions under the prefix (`--system`).
`linto linto uninstall` reverses it; both share `groups/linto/lib/installer.sh`.

Run build after changing configuration or adding or removing executable
scripts. Like `addgroup` and `rmgroup`, `build`, `install` and `addman` are
removed from the Nix package, which provides its own completions and wrappers.

## Argument completion

`linto --complete WORD...` reports how to complete the last word, using the
`# linto-complete:` comments in the command's script (`lib/complete.py` parses
them; the format is described in `linto help completion`). `completions/`
contains thin Bash, Zsh and Fish front ends that call it, so the logic lives in
one place. Fish's argument rules are in `completions/linto-args.fish`, which
`linto.fish` and the file written by `linto linto build` both source. Add a
`# linto-complete:` line to every new command that takes arguments.

## Messages and translations

User-facing description: [`linto help i18n`](linto-guide/i18n.md).

Messages are written in English in the source and translated through
`locale/<lang>.po` (currently `fr.po`). The language comes from `LC_ALL`,
`LC_MESSAGES` or `LANG`, in that order; C, POSIX and English use the source
text, and a string with no translation is shown unchanged. Option, command and
parameter names are never translated.

- Python: `from cli import _` (bib group) or `from i18n import _` with
  `lib/` on the path, then `_("text {}").format(value)`.
- Shell (bib group): `lib/common.sh` provides `_ TEXT`, and `die` and
  `die_usage` take a translated printf format: `die "not a directory: %s" "$dir"`.
  A `usage()` function wraps its whole help text in `_ "$(cat <<'EOF' ... EOF)"`.
- Add each new string to `locale/fr.po` with its French text, keeping the same
  `%s` or `{}` placeholders. `tests/test_i18n.py` checks the catalog and that
  every bib command shows English and French help.

The Python commands of the bib group share `groups/bib/lib/cli.py` (parser with
the same "Usage:" and error style as the shell commands); the shell commands
share `groups/bib/lib/common.sh`.

## Tests

```sh
sh tests/run.sh
```
