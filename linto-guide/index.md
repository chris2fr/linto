# Linto guide

Linto is a local command-line toolbox for bibliography work, Quarto projects,
text processing, and development helpers. This guide is split into topic pages:

- `install` — [Installation and shell setup](install.md)
- `config` — [Group, Markdown-viewer, and Zed configuration](config.md)
- `commands` — Commands and invocation, including shell alias setup
- `bib` — [BibTeX and bibliography workflow](bib.md)
- `quarto` — [Quarto workflow](quarto.md)
- `completion` — [Shell completion and Markdown navigation](completion.md)
- `i18n` — [Language and translations](i18n.md)

Use `linto help PAGE` to read a page in the terminal, for example `linto help
config`. If a page name is also an active group name, select it explicitly with
`linto help page PAGE` (for example, `linto help page bibtex`). `linto help
GROUP` lists the group's current commands, and `linto help GROUP COMMAND` shows
a command's help.

Guide pages are rendered using the first installed program in the
`markdown-viewer` preference list in `config.yml`. If none of the configured
viewers is installed, Linto displays the Markdown as plain text. Set
`LINTO_MDVIEWER` to override the preference list for a single invocation.

For a live list of active groups and commands, run `linto --help`.
