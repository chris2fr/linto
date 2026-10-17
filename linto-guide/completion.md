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
