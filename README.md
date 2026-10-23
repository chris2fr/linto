# Linto

Linto is a small, local command-line toolbox for bibliography work, Quarto
projects, text utilities, and development helpers. The `bin/linto` dispatcher
finds tools relative to this checkout, so commands work from any working
directory.

## Quick start

Install Linto from GitHub, for yourself or for every user of the machine (it needs
`curl` or `wget`, `tar`, `bash` and `python3`):

```sh
curl -fsSL https://raw.githubusercontent.com/chris2fr/linto/main/install.sh | sh -s 
```

Without `--user` or `--system` it asks. The script downloads `chris2fr/linto`, installs a
copy (`~/.local` or `/usr/local`) with its own Python environment, shell completion for
Bash, Zsh, Fish, ksh and sh, and the man page, and records where it came from. Read it
first if you prefer (`install.sh` at the top of this repository); `LINTO_REF` selects a
branch, tag or commit.

Update from the same place:

```sh
linto linto update --check    # is a newer version of chris2fr/linto available?
linto linto update            # download it and reinstall with the same choices
```

To work on Linto itself, clone this repository and run `bin/linto linto install --user`
from the checkout. See [`linto help install`](linto-guide/install.md) for details.

## Nix and NixOS

This repository provides a flake package for `x86_64-linux` and `aarch64-linux`:

```sh
nix profile install .#linto
nix run .#linto -- --help
```

When building from a Git checkout, ensure the flake files are tracked or staged;
Nix excludes untracked files from Git flake sources.

For a NixOS flake, add this checkout as an input (for a local checkout,
`inputs.linto.url = "path:/path/to/linto";`) and import its module:

```nix
imports = [ inputs.linto.nixosModules.default ];
programs.linto = {
  enable = true;
  settings.groups.quarto.configdata.extension = "chris2fr/quarto";
};
```

Optional dependencies are NixOS options rather than a setup step:

```nix
programs.linto = {
  enable = true;
  # Viewers for `linto help`, in order of preference (cat is the fallback).
  # Also installs the packages and sets configdata.markdown-viewer.
  markdownViewers = [ "mdcat" "glow" ];
  # Tools used by individual commands.
  extraPackages = with pkgs; [ quarto zed-editor xdg-utils ];
};
```

`markdownViewers` accepts `md-tui`, `inlyne`, `mdcat`, `mandown`, `glow`,
`frogmouth`, `bat`, and `mdfried`; `mandown` also installs `groff`. This replaces
`linto linto mdsetup`, which is not shipped in the package.

The module installs the package and optionally writes `settings` to
`/etc/linto/linto.yml`; user config still takes precedence. Override
`programs.linto.package` if needed. The package includes the shell/Python
utilities used by Linto and installs Bash, Fish, and Zsh completions. Quarto,
Zed, `xdg-open`, and optional Markdown viewers remain separate packages; add the
ones needed by your workflow to your system configuration. The package does
not ship the installer (`linto linto install`), which is for other
systems, or the development scripts listed in [DEVELOPMENT.md](DEVELOPMENT.md). User configuration
and generated data stay in the XDG locations noted below, outside the immutable
Nix store.

## Running commands

```sh
linto --help                 # show active groups and commands
linto utils prettyprint      # run a command through its group
linto prettyprint            # omit the group when the name is unique
linto-utils-prettyprint      # generated convenience stub, if enabled
linto yml-renumber in.yml
```

Use `linto help PAGE` for a topic guide and `linto help GROUP` to list commands
in a group. If a page name is also a group name, use `linto help page PAGE`.
Individual tools generally support `--help`. The [multi-page Linto
guide](linto-guide/index.md) is also available in the terminal through `linto
help`.

## Group configuration

[`config.yml`](config.yml) is the installation baseline for active groups and
stub policy. Optional system and user files can override it. The YAML mapping
looks like this:

```yaml
configdata:
  markdown-viewer:
    - md-tui
    - cat
groups:
  beta: default
  bib: default
  launch: default
  linto:
    configdata:
      aliases:
        zz: "linto launch zed"
  quarto:
    configdata:
      extension: "chris2fr/quarto"
    commands:
      render:
        enable: true
        configdata: {}
  utils: default
  old:
    enable: false
shortcuts:
  prettyprint: "utils prettyprint"
  stripaccents: "utils stripaccents"
  slug: "utils stripaccents"
  qrencode: "utils qrencode"
  qrdecode: "utils qrdecode"
  guillemets2quotes: "quarto guillemets2quotes"
```

- Built-in group implementations live under `groups/GROUP/`, separate from
  the repository's root-level configuration, dispatcher, and support code.
  `GROUP: default` enables a group. A group mapping may set `enable: false` to
  keep its directory but hide it from Linto, help, completions, and generated
  stubs. Omitted group options default to `enable: true`.
- `enable` remains at the group or command level. Group settings belong under
  `groups.GROUP.configdata`; command settings belong under
  `groups.GROUP.commands.COMMAND.configdata`. Configdata defaults are read from
  [`lib/default.yml`](lib/default.yml), `groups/GROUP/lib/default.yml`, and
  `groups/GROUP/lib/COMMAND.yml`, respectively. Each defaults file stores values
  under `configdata`; corresponding entries in `config.yml` override them. Runtime
  overrides are then merged from `/etc/linto/linto.yml` and
  `${XDG_CONFIG_HOME:-~/.config}/linto/config.yml` (user settings win). A legacy
  `~/.linto.yml` is read below the XDG config; `linto linto install` creates it from `etc/linto.yml`. The shipped Quarto extension
  default is in
  [`groups/quarto/lib/default.yml`](groups/quarto/lib/default.yml); shell-alias
  defaults are in [`groups/linto/lib/default.yml`](groups/linto/lib/default.yml).
  Root settings such as `markdown-viewer` are under top-level `configdata`.
  Writable per-user data,
  including custom groups and generated wrappers/completions/man pages, lives in
  `${XDG_DATA_HOME:-~/.local/share}/linto`.
- Each entry in the top-level `shortcuts` mapping defines an explicit alias:
  the key is the shortcut name, and its value is `"GROUP COMMAND"`. For example,
  `prettyprint: "utils prettyprint"` makes both `linto prettyprint` and
  `linto-prettyprint` run `utils prettyprint`. Aliases are available only when
  their target group is active and the target command is executable.
- Group-qualified `linto GROUP COMMAND` and `linto-GROUP-COMMAND` forms remain
  available for active groups, whether or not an alias is configured.

Commands for regenerating wrappers, completions and man pages, and for managing
groups in a development checkout, are described in
[DEVELOPMENT.md](DEVELOPMENT.md). See [`linto help config`](linto-guide/config.md).

## Main groups

The active groups are listed in `config.yml`. Broadly:

- `bib`: BibTeX/JSON conversion, bibliography formatting, and YAML helpers.
- `quarto`: rendering, citations, Quarto setup, and output browsing.
- `utils`: text, time-zone, and formatting tools.
- `launch`: application launchers such as Zed.
- `linto`: Linto setup and helper commands.
- `beta`: experimental tools.

Use `linto help GROUP` for the live command list. For detailed topics, see
[`linto-guide/`](linto-guide/).

## Documentation and tests

- [`linto-guide/index.md`](linto-guide/index.md): multi-page topic guide for
  installation, config, command usage, bibliography, Quarto, and completion.
- [`man/linto.1`](man/linto.1): dispatcher manual, installed with
  `linto linto addman`.
- Run `tests/run.sh` from the checkout to execute the test suite.
