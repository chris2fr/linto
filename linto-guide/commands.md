# Command usage

The `linto` dispatcher locates commands relative to this checkout, so you can
run them from any current working directory. Common forms are:

```sh
linto --help                         # active groups and commands
linto GROUP                          # show a guide page, then list group commands
linto GROUP COMMAND [ARGUMENTS...]   # explicitly select a group
linto COMMAND [ARGUMENTS...]         # use a unique command name
linto-GROUP-COMMAND [ARGUMENTS...]   # generated group-qualified stub
```

When enabled by the group's `short-stubs` setting, unique commands also have a
`linto-COMMAND` stub. A command's own help is generally available through
`linto COMMAND --help` or `linto help GROUP COMMAND`.

`linto help` displays the guide index. Use `linto help PAGE` to read a guide
topic, or `linto help page PAGE` when the topic name is also an active group
name. For example, `bibtex` is both a guide topic and a group, so use
`linto help page bibtex` to select its guide page. The group listing takes
precedence for `linto help GROUP`.

The dispatcher also supports `slug` as an alias for `stripaccents`. Run
`linto --list-groups` to list active groups and `linto --list-commands GROUP`
to list a group's commands.

## Shell aliases

`linto launch aliases` installs or updates aliases declared in
[`launch/lib/aliases.yml`](../launch/lib/aliases.yml) for one shell. For example:

```yaml
aliases:
  zz: "linto launch zed"
unaliases:
  - old-alias
```

By default, the command detects the shell from `$SHELL`, then tries the parent
process, and falls back to `sh` if it cannot identify one. Select a shell
explicitly with `-s` or `--shell`:

```sh
linto launch aliases --shell fish
linto launch aliases -s bash
```

Choices are `fish`, `zsh`, `bash`, `sh`, and `ksh`. Fish aliases are saved with
Fish's `alias --save` mechanism. For Bash, Zsh, sh, and ksh, Linto replaces the
managed alias block in `~/.bashrc`, `~/.zshrc`, `~/.profile`, or `~/.kshrc`,
respectively. Names listed in `unaliases` are omitted from the managed aliases;
for Fish, Linto also erases the saved alias function. Start a new shell or reload
your shell's configuration for the changes to take effect.
