#!/bin/sh
# linto-complete: opt -l,--lang choices:la,fr,en Language of the text
# linto-complete: opt --seed value Seed for reproducible output
# linto-complete: flag -p,--paragraphs Produce paragraphs (default)
# linto-complete: flag -s,--sentences Produce sentences
# linto-complete: flag -w,--words Produce words
# linto-complete: flag --no-classic-opening Do not start with "Lorem ipsum"
# linto-complete: arg 1 value
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/lorem.py" "$@"
