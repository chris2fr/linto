#!/bin/sh
# linto-complete: opt -o,--output *.json Output file (single input)
# linto-complete: opt --outdir dir Output directory (several inputs)
# linto-complete: opt --format choices:simple,structured,flat,metadata JSON shape
# linto-complete: flag --pretty Indent the JSON
# linto-complete: arg * *.md
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/md2json.py" "$@"
