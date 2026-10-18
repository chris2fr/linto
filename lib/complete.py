"""Decide how to complete the arguments of one Linto command.

Usage: complete.py TOOL [WORD...]

TOOL is the command's script. WORD... are the words typed after the command
name, the last one being the word under the cursor (possibly empty).

A command declares what its arguments look like in `# linto-complete:` comments
near the top of its script:

    # linto-complete: arg 1 *.bib          first positional argument
    # linto-complete: arg * *.qmd,*.md     every other positional argument
    # linto-complete: opt -j,--json *.json option taking a value
    # linto-complete: flag -i,-i.bak       option taking no value

A KIND is one of: `file` (any file or directory), `dir`, a comma-separated list
of globs such as `*.qmd,*.md` (matching files, plus directories to descend
into), `choices:a,b,c`, or `value` (free text, nothing to complete). Commands
that declare nothing complete any file.

The first line printed is the kind of completion for the shell to do:

    files<TAB>GLOB,GLOB    files matching the globs (all files if none)
    dirs                   directories only
    words                  the following lines are the candidates
    none                   nothing to complete
"""

import sys

MAX_HEADER_LINES = 60
PREFIX = "# linto-complete:"


def parse_directives(path):
    positional = {}
    options = {}
    flags = set()
    declared = False
    try:
        with open(path, encoding="utf-8", errors="replace") as script:
            for number, line in enumerate(script):
                if number >= MAX_HEADER_LINES:
                    break
                line = line.strip()
                if not line.startswith(PREFIX):
                    continue
                fields = line[len(PREFIX):].split()
                declared = True
                if len(fields) == 3 and fields[0] == "arg":
                    positional[fields[1]] = fields[2]
                elif len(fields) == 3 and fields[0] == "opt":
                    for name in fields[1].split(","):
                        options[name] = fields[2]
                elif len(fields) == 2 and fields[0] == "flag":
                    flags.update(fields[1].split(","))
    except OSError:
        pass
    return declared, positional, options, flags


def split_words(words, options, flags):
    """Return (positionals typed before the cursor, option waiting for a value)."""
    positionals = 0
    pending = None
    after_double_dash = False
    for word in words:
        if pending is not None:
            pending = None
        elif after_double_dash:
            positionals += 1
        elif word == "--":
            after_double_dash = True
        elif word in options:
            pending = word
        elif word.startswith("--") and "=" in word:
            pass
        elif word.startswith("-") and len(word) > 2 and word[:2] in options:
            pass
        elif word.startswith("-") and word != "-":
            pass
        else:
            positionals += 1
    return positionals, pending


def emit(kind):
    if kind == "file":
        print("files")
    elif kind == "dir":
        print("dirs")
    elif kind == "value":
        print("none")
    elif kind.startswith("choices:"):
        print("words")
        for choice in kind[len("choices:"):].split(","):
            print(choice)
    else:
        print("files\t" + kind)


def main(argv):
    if not argv:
        return 0
    tool, words = argv[0], argv[1:] or [""]
    declared, positional, options, flags = parse_directives(tool)
    if not declared:
        emit("file")
        return 0

    typed, current = words[:-1], words[-1]
    count, pending = split_words(typed, options, flags)

    if pending is not None:
        emit(options[pending])
    elif current.startswith("-") and "--" not in typed:
        print("words")
        for name in sorted({*options, *flags, "-h", "--help"}):
            print(name)
    else:
        kind = positional.get(str(count + 1)) or positional.get("*")
        emit(kind or "value")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
