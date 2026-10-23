# Command usage

The `linto` dispatcher locates commands relative to this checkout, so you can
run them from any current working directory. Common forms are:

```sh
linto --help                         # active groups and commands
linto GROUP                          # show a guide page, then list group commands
linto GROUP COMMAND [ARGUMENTS...]   # explicitly select a group
linto SHORTCUT [ARGUMENTS...]       # explicitly configured shortcut alias
linto-SHORTCUT [ARGUMENTS...]       # generated shortcut stub
linto-GROUP-COMMAND [ARGUMENTS...]   # generated group-qualified stub
```

`linto GROUP COMMAND` and `linto-GROUP-COMMAND` always address a command in a
specific active group. Unqualified `linto SHORTCUT` and `linto-SHORTCUT` forms
are created only for aliases explicitly listed in the top-level `shortcuts`
mapping. Each alias maps to one `"GROUP COMMAND"` target, so it can disambiguate
commands with the same name in different groups. A command's help is available
through `linto help GROUP COMMAND`; `linto SHORTCUT --help` works for configured
aliases.

`linto help` displays the guide index. Use `linto help PAGE` to read a guide
topic, or `linto help page PAGE` when the topic name is also an active group
name. For example, `bibtex` is both a guide topic and a group, so use
`linto help page bibtex` to select its guide page. The group listing takes
precedence for `linto help GROUP`.

The configured `slug` shortcut maps to `utils stripaccents`. Run
`linto --list-groups` to list active groups and `linto --list-commands GROUP`
to list a group's commands.

## Shell aliases

`linto linto aliases` installs or updates the shell aliases in
`groups.linto.configdata.aliases`. Group-specific values go in
[`config.yml`](../config.yml); defaults are in [`groups/linto/lib/default.yml`](../groups/linto/lib/default.yml).
For example:

```yaml
groups:
  linto:
    configdata:
      aliases:
        zz: "linto launch zed"
```

By default, the command detects the shell from `$SHELL`, then tries the parent
process, and falls back to `sh` if it cannot identify one. Select a shell
explicitly with `-s` or `--shell`:

```sh
linto linto aliases --shell fish
linto linto aliases -s bash
```

Choices are `fish`, `zsh`, `bash`, `sh`, and `ksh`. Fish aliases are saved with
Fish's `alias --save` mechanism. For Bash, Zsh, sh, and ksh, Linto replaces the
managed alias block in `~/.bashrc`, `~/.zshrc`, `~/.profile`, or `~/.kshrc`,
respectively. Start a new shell or reload your shell's configuration for the
changes to take effect.

## Memos (`linto web memos`)

`linto web memos ACTION` works with a [Memos](https://www.usememos.com) server
through its REST API v1: `list` (`-t TAG`, `-q TEXT`, `--visibility`, `-n`,
`--json`), `get ID`, `add [-v LEVEL] [TEXT]`, `edit ID [TEXT]` and
`delete ID` (`--yes`). Text not given on the command line is read from
standard input. Set the server in `groups.web.configdata.memos.url` (or
`LINTO_MEMOS_URL`) and a personal access token in
`groups.web.configdata.memos.token-file` (or `LINTO_MEMOS_TOKEN`).

`linto utils timer` and `linto utils countdown DURATION` show their own display, but
hand over to [`tclock`](https://github.com/race604/clock-tui) (package `clock-tui`) when it is
installed and the output is a terminal: `timer` runs `tclock stopwatch` and prints the
elapsed time when you quit it; `countdown` runs `tclock timer -d DURATION` (tclock's own
`countdown` counts down to a date and time, not for a duration) and then rings the bell,
prints the message and runs the command if the time ran out, or exits with status 130 if you
quit it earlier. `--plain`, or `tclock: false` in `groups.utils.configdata`, keeps the
built-in display; `timer --laps` always does, since tclock has no laps.

`linto utils qrdecode [--backend zbar|opencv] FILE...` reads QR codes with the first
available backend of `groups.utils.configdata.qrdecode.backends`. The default is
`[zbar]`: the `zbarimg` command (package `zbar-tools`), which is small and needs no
Python package. Add `opencv` to the list, or pass `--backend opencv`, for the Python
decoder, which offers to install its optional packages (about 150 MB) on first use.

`linto web memos get REF` accepts a number from 0 to 100 (the N-th memo from
the top of `list`; 0 is the first), `YYYY-MM-DD-NN` (the NN-th memo created on
that day in local time, from `00`, oldest first), or a memo id such as `123`
or `memos/123`. Ids up to 100 need the `memos/` prefix.

On a terminal, `get` renders the memo's Markdown with the first installed
viewer of `groups.web.configdata.markdown`: a list of command lines that read
Markdown on standard input (by default `mdcat`, `glow -`, then `bat`). Use
`--markdown` or `--no-markdown` to force or disable it; without an installed
viewer the plain text is printed.
