#!/bin/sh
# linto-complete: opt --order-by choices:appearance,key
# linto-complete: opt --format choices:yml,yaml,csv
# linto-complete: opt --start value
# linto-complete: opt -y,--yml *.yml,*.yaml
# linto-complete: arg 1 *.qmd,*.md
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/qmd2yml.py" "$@"
