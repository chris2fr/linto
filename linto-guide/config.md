# Configuration

The repository's [`config.yml`](../config.yml) controls active command groups,
generated command stubs, the Quarto extension default, and Markdown viewer
preferences.

## Groups and command stubs

The `groups` mapping accepts the `default` shorthand or a mapping of options:

```yaml
groups:
  beta: default
  biblo: default
  launch: default
  linto:
    short-stubs: false
  quarto:
    short-stubs: false
  utils: default
  old:
    enable: false
  biblio: default
```

`default` enables a group and uses the defaults `enable: true` and
`short-stubs: true`. A mapping may set `enable: false` to leave a directory in
the checkout while making Linto ignore it for dispatch, help, completions, and
stubs. `short-stubs: true` adds `linto-COMMAND` stubs for command names unique
across enabled groups. Group-qualified calls such as `linto GROUP COMMAND` and
stubs such as `linto-GROUP-COMMAND` remain available.

## Markdown viewer

`markdown-viewer` accepts one command name or an ordered YAML list. Linto tries
the entries from top to bottom and runs the first installed supported viewer.
For example:

```yaml
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

Refresh regenerates command stubs, shell completion data, the active-group list
in the dispatcher man page, and one man page per `linto-guide/*.md` topic. Topic
man pages are installed under `man/man1/` after generation succeeds and each
page passes `groff -Wall` validation. `mandown` and `groff` are required for this
step.

Register or re-enable a group with `linto linto addgroup DIRECTORY`. Remove a
group from Linto's active configuration with `linto linto rmgroup GROUP`; this
does not delete the group directory. Use `linto --list-groups` to inspect active
groups.
