#!/bin/sh
# linto-complete: flag --plus Decode + as a space
# linto-complete: arg * value
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/urlcodec.py" decode "$@"
