# Installation and setup

Add this checkout's `bin/` directory to your `PATH`, or run the setup helper to
configure your current shell:

```sh
linto-linto-setup
```

The setup helper is safe to run more than once. It configures supported shell
startup files for Bash, Zsh, and other detected shells. To install the `linto(1)`
man page as well:

```sh
linto-linto-setup --man
```

If `man linto` is not found, ensure your user man directory is included in
`MANPATH`. Run `linto-linto-addman --help` for details.

You can also configure `PATH` manually:

```sh
export PATH="/path/to/linto/bin:$PATH"
```

The path `/path/to/linto` should be replaced with this checkout's actual
location. See [Shell completion](completion.md) for optional tab completion.
