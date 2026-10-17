# Group configuration

The repository's [`config.yml`](../config.yml) is the source of truth for active
groups and generated command stubs. Its `groups` mapping accepts the `default`
shorthand or a mapping of options, for example:

```yaml
markdown-viewer: cat # bat inlyne glow frogmouth mandown mdcat mdfried mdless md-tui
groups:
  beta: default
  bibtex: default
  launch: default
  linto:
    short-stubs: false
  quarto:
    short-stubs: false
  utils: default
  old:
    enable: false
```

`default` enables a group and uses the defaults: `enable: true` and
`short-stubs: true`. A mapping may set `enable: false` to leave a directory in
the checkout while making Linto ignore it for dispatch, help, completions, and
stubs. `short-stubs: true` adds `linto-COMMAND` stubs for command names unique
across enabled groups. Group-qualified calls such as `linto GROUP COMMAND` and
stubs such as `linto-GROUP-COMMAND` remain available.

After editing configuration or adding/removing executable scripts, regenerate
the command stubs, completion data, and active group list in the man page:

```sh
linto linto refresh
```

Register or re-enable a group with `linto linto addgroup DIRECTORY`. Remove a
group from Linto's active configuration with `linto linto rmgroup GROUP`; this
does not delete the group directory. Use `linto --list-groups` to inspect active
groups.
