# Linto

Linto is a small, local command-line toolbox for bibliography work, Quarto
projects, text utilities, and development helpers. The `bin/linto` dispatcher
finds tools relative to this checkout, so commands work from any working
directory.

## Quick start

Add this checkout's `bin/` directory to your `PATH`, then configure completion
for your shell:

```sh
export PATH="/path/to/linto/bin:$PATH"
```

Or use Linto's setup helper for Bash, Zsh, or Fish:

```sh
linto-linto-setup
```

Install the `linto(1)` man page too with `linto-linto-setup --man`. See
[`linto help install`](linto-guide/install.md) for details.

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

[`config.yml`](config.yml) is the source of truth for active groups and stub
policy. It uses a YAML mapping:

```yaml
groups:
  beta: default
  biblio: default
  launch: default
  linto: default
  quarto: default
  utils: default
  old:
    enable: false
shortcuts:
  prettyprint: "utils prettyprint"
  stripaccents: "utils stripaccents"
  guillemets2quotes: "quarto guillemets2quotes"
```

- `GROUP: default` enables a group. A group mapping may set `enable: false` to
  keep its directory but hide it from Linto, help, completions, and generated
  stubs. Omitted group options default to `enable: true`.
- Each entry in the top-level `shortcuts` mapping defines an explicit alias:
  the key is the shortcut name, and its value is `"GROUP COMMAND"`. For example,
  `prettyprint: "utils prettyprint"` makes both `linto prettyprint` and
  `linto-prettyprint` run `utils prettyprint`. Aliases are available only when
  their target group is active and the target command is executable.
- Group-qualified `linto GROUP COMMAND` and `linto-GROUP-COMMAND` forms remain
  available for active groups, whether or not an alias is configured.

Refresh generated command stubs, Fish completions, and the active-group list in
the man page after changing configuration or scripts:

```sh
linto linto refresh
```

`linto linto addgroup DIRECTORY` registers or re-enables a group; `linto linto
rmgroup GROUP` removes a `default` entry or disables a mapped group. Neither
command deletes an existing group directory. See [`linto help config`](linto-guide/config.md).

## Main groups

The active groups are listed in `config.yml`. Broadly:

- `bibtex`: BibTeX/JSON conversion, bibliography formatting, and YAML helpers.
- `quarto`: rendering, citations, Quarto setup, and output browsing.
- `utils`: text, time-zone, and formatting tools.
- `launch`: application launchers such as Zed.
- `linto`: Linto setup, group management, and refresh commands.
- `beta`: experimental tools.

Use `linto help GROUP` for the live command list. For detailed topics, see
[`linto-guide/`](linto-guide/).

## Documentation and tests

- [`linto-guide/index.md`](linto-guide/index.md): multi-page topic guide for
  installation, config, command usage, bibliography, Quarto, and completion.
- [`man/linto.1`](man/linto.1): dispatcher manual, installed with
  `linto-linto-addman`.
- Run `tests/run.sh` from the checkout to execute the test suite.
