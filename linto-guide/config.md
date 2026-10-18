# Configuration

The installation's [`config.yml`](../config.yml) provides the baseline for
active command groups, generated stubs, and shortcuts. Optional system and user
configuration files override it at runtime. Defaults supply the Quarto extension
and Markdown viewer preferences.

## Groups and shortcuts

The `groups` mapping accepts the `default` shorthand or a mapping of options.
Settings are separated into `enable`, `configdata`, and `commands`:

```yaml
configdata:
  markdown-viewer:
    - md-tui
    - cat
groups:
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
shortcuts:
  prettyprint: "utils prettyprint"
  stripaccents: "utils stripaccents"
  slug: "utils stripaccents"
  guillemets2quotes: "quarto guillemets2quotes"
```

`default` enables a group. A group mapping may set `enable: false` to leave a
directory in the checkout while making Linto ignore it for dispatch, help,
completions, and stubs. Omitted group and command `enable` options default to
`true`; command enable values live at
`groups.GROUP.commands.COMMAND.enable`.

Group-specific settings live under `groups.GROUP.configdata`, and command-
specific settings under `groups.GROUP.commands.COMMAND.configdata`. Defaults
are layered from `lib/default.yml` (root), `groups/GROUP/lib/default.yml` (group), and
`groups/GROUP/lib/COMMAND.yml` (command). Each defaults file stores values under
`configdata`, and matching entries in the installation's `config.yml` override
them. At runtime, `/etc/linto/linto.yml` is merged next, then
`${XDG_CONFIG_HOME:-~/.config}/linto/config.yml`, so user settings have the
highest precedence. A legacy `~/.linto.yml` is read below the XDG config file.
These files may contain only the settings they override. The config command
supports these inspection and editing modes:

- `linto linto config` prints the user config directory and file path.
- `linto linto config --init` copies the packaged `config.yml` there if no user
  config exists; it refuses to overwrite an existing file.
- `linto linto config --group quarto` shows effective configdata for a group;
  add `--command render` for command-level configdata.
- `linto linto config --effective` prints the full configuration with defaults
  and overrides merged. This report is informational, not intended to be copied
  back as a user override.
- `linto linto config --edit` opens the user file with `linto launch zed`; pass
  `--editor PROGRAM` to use another executable. If needed, it creates an empty
  user override file.

Defaults are located relative to the Linto installation, not the current working
directory. The Markdown viewer is root configdata, while the shipped
Quarto extension and Linto shell-alias defaults are in
[`groups/quarto/lib/default.yml`](../groups/quarto/lib/default.yml) and
[`groups/linto/lib/default.yml`](../groups/linto/lib/default.yml), respectively.

The top-level `shortcuts` mapping defines explicit aliases. Each key is the
shortcut name, and each value is a `"GROUP COMMAND"` target. For example,
`prettyprint: "utils prettyprint"` makes both `linto prettyprint` and
`linto-prettyprint` run the `utils prettyprint` command. Aliases are listed and
usable only when their target group is active and the target command exists and
is executable. This explicit mapping avoids ambiguous shortcuts when commands
share a name across groups. Group-qualified commands remain available without
any alias entry.

## Markdown viewer

`configdata.markdown-viewer` accepts one command name or an ordered YAML list.
Linto tries the entries from top to bottom and runs the first installed supported viewer.
For example:

```yaml
configdata:
  markdown-viewer:
    - mdless
    - mdcat
    - glow
    - bat
    - cat
```

Supported choices include `md-tui`, `inlyne`, `mdcat`, `mandown`, `glow`,
`frogmouth`, `mdless`, `mdfried`, `bat`, and `cat`. `mandown` is selected only
when `groff` is also installed. If no configured viewer is available, Linto
falls back to `cat`. Set `LINTO_MDVIEWER` to override the configured list for a
single invocation, for example `LINTO_MDVIEWER=cat linto help config`.

The `linto linto mdsetup` command reports the selected viewer and attempts to
install Markdown prerequisites when needed. It does not install every optional
viewer.

## Zed data sharing

The Zed launcher accepts `-u DIR`/`--userdatadir DIR`; projects using the same
root use the same `DIR/.zed` user-data directory. Without this option, a folder
argument uses that folder as the user-data root. When opening a file, the user-
data root defaults to the current working directory. `--projectdir DIR` sets the
project directory explicitly.

For a file argument, the project directory defaults to the current working
directory if the file is inside it; otherwise it defaults to the file's parent
directory. A folder argument opens that folder as the project.

When initializing a non-default `.zed` directory, the launcher copies the
non-shared contents of `$HOME/.zed` into it, then links `languages` and
`extensions` back to `$HOME/.zed` when those shared directories exist. The
initialization is headless; it does not open a temporary Zed window. Existing
project-specific data in the destination is preserved.

## Refresh generated files

After editing configuration or adding/removing executable scripts, run:

```sh
linto linto refresh
```

Refresh writes generated command wrappers, Fish completions, and man pages to
`${XDG_DATA_HOME:-~/.local/share}/linto`, never into the installation tree. This
is also where custom groups added with `linto linto addgroup DIRECTORY` are
stored. The setup helper adds the generated wrapper directory to `PATH`. Remove
a group with `linto linto rmgroup GROUP`; it is disabled in the user config, but
its files are left untouched. Use `linto --list-groups` to inspect active groups.

The installation requires `mandown` and `groff` when refreshing generated man
pages. This is convenient on mutable systems and should be declared as runtime
inputs by Nix packages that expose the refresh command.
