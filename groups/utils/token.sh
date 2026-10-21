#!/bin/sh
# linto-complete: opt -l,--length value Token length (default: 32)
# linto-complete: opt -n,--count value How many tokens to print (default: 1)
# linto-complete: flag --upper Include upper-case letters (default)
# linto-complete: flag --no-upper Leave out upper-case letters
# linto-complete: flag --lower Include lower-case letters (default)
# linto-complete: flag --no-lower Leave out lower-case letters
# linto-complete: flag --numbers Include digits (default)
# linto-complete: flag --no-numbers Leave out digits
# linto-complete: flag --symbols Include symbols
# linto-complete: flag --no-symbols Leave out symbols (default)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/tokencmd.py" "$@"
