# Shell completion and Markdown navigation

Linto includes Bash, Zsh, and Fish completion definitions. Ask the dispatcher
for the setup instruction for your shell:

```sh
linto completion bash
linto completion zsh
linto completion fish
```

For Zsh, add the printed `fpath` setup and `compinit` line to your Zsh startup
configuration (normally `~/.zshrc`), or run `linto linto setup` to configure a
supported shell automatically. Restart the shell or source the updated
configuration. Fish completion is optional; it is not required for Linto or for
Bash/Zsh completion.

## Navigating with mdless

If `mdless` is installed and comes before other installed viewers in the
`markdown-viewer` preference list, it will be selected to display guide pages.
Use these keys while viewing a page:

- `j`/`k` or the arrow keys to scroll.
- Space or `f` to page down; `b` to page up.
- `/` to search; `n`/`N` to move between matches.
- `g`/`G` to jump to the beginning/end.
- `q` to quit; `h` to open `mdless`'s built-in help.
