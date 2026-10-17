# Installation and setup

Add this checkout's `bin/` directory to your `PATH`, or run the setup helper to
configure the current user's shell:

```sh
linto-linto-setup
```

The helper supports Bash, Zsh, and Fish and can be run more than once. To
configure shell completion and install the `linto(1)` man page as well:

```sh
linto-linto-setup --man
```

If `man linto` is not found, ensure your user man directory is included in
`MANPATH`. Run `linto-linto-addman --help` for details.

To set up Markdown-viewer prerequisites, run:

```sh
linto linto mdsetup
```

This reports the configured available viewer and attempts to install `mdcat`
and `mandown` when needed. It does not install every optional viewer. Viewer
preference and ordering are configured with `markdown-viewer` in `config.yml`;
see [Group and Markdown-viewer configuration](config.md).

You can also configure `PATH` manually:

```sh
export PATH="/path/to/linto/bin:$PATH"
```

Replace `/path/to/linto` with this checkout's actual location. See
[Shell completion and Markdown navigation](completion.md) for tab completion.
