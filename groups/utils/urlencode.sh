#!/bin/sh
# linto-complete: opt --safe value Characters to leave unencoded
# linto-complete: flag --plus Encode spaces as plus signs
# linto-complete: arg * value
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/urlcodec.py" encode "$@"
