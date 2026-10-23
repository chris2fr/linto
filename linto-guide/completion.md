# Shell completion and Markdown navigation

Linto includes Bash, Zsh, and Fish completion definitions. Ask the dispatcher
for the setup instruction for your shell:

```sh
linto completion bash
linto completion zsh
linto completion fish
```

For Zsh, add the printed `fpath` setup and `compinit` line to your Zsh startup
configuration (normally `~/.zshrc`), or run `linto linto install` to configure the
supported shells automatically. Restart the shell or source the updated
configuration. Fish completion is optional; it is not required for Linto or for
Bash/Zsh completion.

## What Tab completes

Beyond group and command names, Tab completes the arguments of each command
according to what it accepts. For example `linto quarto render` offers only
`.qmd` and `.md` files (and directories to descend into), `linto bib
bib2json -j` offers `.json` files, `linto utils stripaccents -d` offers only
directories, and `linto prettyprint -f` offers the font names. Typing `-` lists
the command's options. Commands that take no arguments complete nothing.

Completion works for the `linto GROUP COMMAND` form, for shortcuts, and for the
`linto-GROUP-COMMAND` aliases.

## Declaring a command's arguments

A command describes its arguments in `# linto-complete:` comments near the top
of its script (the first 60 lines). This is read by `linto --complete`, which
the three shells share, so a new command needs nothing more:

```sh
# linto-complete: arg 1 *.bib            first positional argument
# linto-complete: arg * *.qmd,*.md       every other positional argument
# linto-complete: opt -j,--json *.json   option that takes a value
# linto-complete: flag -i,-i.bak         option that takes no value
# linto-complete: none                   the command takes no arguments
```

Text after the kind of an `opt` (or after the names of a `flag`) is its
description, shown next to the option by Fish and Zsh, for example
`# linto-complete: opt -j,--json *.json Input JSON to complete`.

The kind of an argument or option value is one of:

- `file`: any file or directory;
- `dir`: directories only;
- a comma-separated list of globs such as `*.qmd,*.md`: matching files, plus
  directories so you can navigate;
- `choices:a,b,c`: a fixed list of words;
- `value`: free text, nothing is offered.

A command that declares nothing completes any file. `--option=value` is not
completed.

## Navigating with mdless

If `mdless` is installed and comes before other installed viewers in the
`markdown-viewer` preference list, it will be selected to display guide pages.
Use these keys while viewing a page:

- `j`/`k` or the arrow keys to scroll.
- Space or `f` to page down; `b` to page up.
- `/` to search; `n`/`N` to move between matches.
- `g`/`G` to jump to the beginning/end.
- `q` to quit; `h` to open `mdless`'s built-in help.
