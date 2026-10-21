#!/bin/sh
# linto-complete: arg 1 *.yml,*.yaml
# linto-complete: arg 2 *.yml,*.yaml
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/renumberyml.py" "$@"
