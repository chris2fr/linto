#!/bin/sh
# linto-complete: arg 1 choices:list,get,add,edit,delete
# linto-complete: arg * value
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/memos.py" "$@"
