#!/bin/sh
# linto-complete: opt -o,--output *.json
# linto-complete: opt --outdir dir
# linto-complete: opt --format choices:simple,structured,flat,metadata
# linto-complete: flag --pretty
# linto-complete: arg * *.md
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/md2json.py" "$@"
