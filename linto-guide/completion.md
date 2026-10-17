# Shell completion

Linto includes Bash, Zsh, and Fish completion definitions. Ask the dispatcher
for the setup instruction for your shell:

```sh
linto completion bash
linto completion zsh
linto completion fish
```

For Zsh, add the printed `fpath` setup and `compinit` line to your Zsh startup
configuration (normally `~/.zshrc`), or run `linto-linto-setup` to configure a
supported shell automatically. Restart the shell or source the updated
configuration. Fish completion is optional; it is not required for Linto or for
Bash/Zsh completion.

When guide pages are displayed with `mdless`, navigate with `j`/`k` or the arrow
keys, use Space or `f` to page down and `b` to page up, and press `/` to search
(`n`/`N` move between matches). Press `g`/`G` to jump to the start/end, `q` to
quit, or `h` for `mdless`'s built-in help.
