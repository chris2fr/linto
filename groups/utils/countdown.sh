#!/bin/sh
# linto-complete: opt -m,--message value Message printed when time is up
# linto-complete: flag --no-bell Do not ring the bell
# linto-complete: arg 1 value
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/stopwatch.py" countdown "$@"
