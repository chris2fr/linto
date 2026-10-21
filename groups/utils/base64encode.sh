#!/bin/sh
# linto-complete: flag --urlsafe Use the URL-safe alphabet
# linto-complete: flag --no-padding Omit the = padding
# linto-complete: arg * value
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/base64codec.py" encode "$@"
