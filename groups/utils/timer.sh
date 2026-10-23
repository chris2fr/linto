#!/bin/sh
# linto-complete: flag -l,--laps Press Enter to record a lap
# linto-complete: flag --plain Do not hand over to tclock
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/stopwatch.py" timer "$@"
