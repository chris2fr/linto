#!/bin/sh
# linto-complete: opt -n,--count value How many UUIDs to print (default: 1)
# linto-complete: opt -v,--version choices:1,4,7 UUID version (default: 4)
# linto-complete: flag -u,--upper Print in upper case
# linto-complete: flag --no-hyphens Print without hyphens
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/uuid_cmd.py" "$@"
