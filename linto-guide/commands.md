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
