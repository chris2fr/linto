# Installation and setup

Run the installer. It asks whether to install for the current user or for all
users; give `--user` or `--system` to skip the question:

```sh
linto linto install --user
sudo linto linto install --system
```

`--user` runs Linto in place from this checkout. It builds the command
wrappers, completions and man pages (`linto linto build`) into
`${XDG_DATA_HOME:-~/.local/share}/linto`, adds this installation's `bin/` and
that per-user `bin/` directory to your `PATH`, and installs completion, for
every supported shell by default: Fish, Bash, ksh, sh and Zsh. Choose some with
`--shell` (repeat it or separate shells with commas). The installer can be run
more than once; ksh and sh get the PATH entries but no completion. Use
`--no-man` to skip the man page and `--venv` to create the Python environment
too (`linto linto venv`).

`--system` copies Linto to `PREFIX/lib/linto`, builds its wrappers into
`PREFIX/share/linto`, links the commands into `PREFIX/bin`, and installs the
completions and man pages under `PREFIX/share` (`--prefix`, default
`/usr/local`). It needs write access to the prefix, normally root. Run it again
to upgrade. Each user can still add their own configuration and groups, which
are stored under their home directory. The
XDG variables are optional: without them, user configuration is stored in
`~/.config/linto/config.yml`, and custom groups/generated data live in
`~/.local/share/linto`. No Linto-specific home variable is required. An existing
`~/.linto.yml` is the per-user configuration file; `~/.config/linto/config.yml`,
when it exists, is read above it. `--user` creates `~/.linto.yml` from the
template `etc/linto.yml` if you have neither; `--system` creates
`/etc/linto/linto.yml` the same way (`--sysconfdir` changes `/etc`) and never
overwrites either file. The system installation's own `config.yml` comes from
the neutral template `etc/config.yml`, so personal settings of the checkout it
was installed from are not shipped to other users.

On NixOS, `linto linto install` changes nothing and prints the equivalent
`programs.linto` options instead (see the README's Nix section).

The `linto(1)` man page is installed too; if `man linto` is not found, ensure your user man directory is included in
`MANPATH`. Run `linto linto addman --help` for details.

To set up Markdown-viewer prerequisites, run:

```sh
linto linto mdsetup
```

This reports the configured available viewer and attempts to install `mdcat`
and `mandown` when needed. It does not install every optional viewer. Viewer
preference and ordering are configured with `configdata.markdown-viewer` in the
installation or user config;
see [Group and Markdown-viewer configuration](config.md).

You can also configure `PATH` manually:

```sh
export PATH="/path/to/linto/bin:$PATH"
```

Replace `/path/to/linto` with this checkout's actual location. See
[Shell completion and Markdown navigation](completion.md) for tab completion.
