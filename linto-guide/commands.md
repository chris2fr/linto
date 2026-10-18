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
[`config.yml`](../config.yml); defaults are in [`linto/lib/default.yml`](../linto/lib/default.yml).
For example:

```yaml
groups:
  linto:
    configdata:
      aliases:
        zz: "linto launch zed"
```

By default, the command detects the shell invoking Linto by walking the
parent-process chain (skipping shell processes running Linto scripts), then
falls back to shell environment variables and `$SHELL`. Select a shell
explicitly with `-s` or `--shell`:

```sh
linto linto aliases --shell fish
linto linto aliases -s bash
linto linto aliases --shell all
```

Choices are `fish`, `zsh`, `bash`, `sh`, `ksh`, and `all`. `all` updates each
of the five shells. Fish aliases are saved with Fish's `alias --save` mechanism.
For Bash, Zsh, sh, and ksh, Linto replaces the managed alias block in
`~/.bashrc`, `~/.zshrc` (or `$ZDOTDIR/.zshrc`), `~/.profile`, or `~/.kshrc`,
respectively. Start a new shell or reload the relevant startup file for changes
to take effect. Setup detects the invoking shell too; use
`linto linto setup --shell SHELL` to override it. Setup supports Bash, Zsh, and
Fish.
