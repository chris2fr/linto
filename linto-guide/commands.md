# Command usage

The `linto` dispatcher locates commands relative to this checkout, so you can
run them from any current working directory. Common forms are:

```sh
linto --help                         # active groups and commands
linto GROUP                          # list commands in a group
linto GROUP COMMAND [ARGUMENTS...]   # explicitly select a group
linto COMMAND [ARGUMENTS...]         # use a unique command name
linto-GROUP-COMMAND [ARGUMENTS...]   # generated group-qualified stub
```

When enabled by the group's `short-stubs` setting, unique commands also have a
`linto-COMMAND` stub. A command's own help is generally available through
`linto COMMAND --help` or `linto help GROUP COMMAND`.

The dispatcher also supports `slug` as an alias for `stripaccents`. Run
`linto help GROUP` to list a group's current commands, or `linto help PAGE` to
read a guide topic. The group listing takes precedence if a topic has the same
name as a group.
