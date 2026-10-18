# Development

Notes for working in a Linto git checkout. These are not part of the Nix
package or the user guide.

## Group management scripts

`addgroup` and `rmgroup` edit the checkout's own `config.yml`, so they only make
sense on a mutable source tree. They are removed from the Nix package, whose
store tree is read-only. Installed systems enable or disable groups through the
`groups` mapping in `~/.config/linto/config.yml` or `programs.linto.settings`.

- `linto linto addgroup DIRECTORY` registers or re-enables a group.
- `linto linto rmgroup GROUP` removes a `default` entry or disables a mapped
  group.

Neither command deletes an existing group directory.

## Refresh and man pages

`linto linto refresh` regenerates command wrappers, Fish completions, the
active-group list in the dispatcher man page, and one man page per
`linto-guide/*.md` topic. Output goes to `${XDG_DATA_HOME:-~/.local/share}/linto`,
never into the checkout. It requires `mandown` and `groff`
(`linto linto mdsetup`). `linto linto addman` runs refresh and links the
generated man page into the user's man path. `addgroup` and `rmgroup` also run
refresh.

Run refresh after changing configuration or adding or removing executable
scripts. Like `addgroup` and `rmgroup`, `refresh` and `addman` are removed from
the Nix package, which provides its own completions and wrappers.

## Tests

```sh
sh tests/run.sh
```
