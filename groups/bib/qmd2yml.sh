#!/bin/sh
# linto-complete: opt --order-by choices:appearance,key Order of the new keys
# linto-complete: opt --format choices:yml,yaml,csv Output format
# linto-complete: opt --start value First number when there is no --yml
# linto-complete: opt -y,--yml *.yml,*.yaml Existing YAML mapping to extend
# linto-complete: opt -o,--output value Output file (default: stdout)
# linto-complete: arg 1 *.qmd,*.md
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/qmd2yml.py" "$@"
