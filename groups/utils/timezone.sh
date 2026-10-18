#!/bin/sh
# linto-complete: opt -s,--source-timezone value Source IANA time zone
# linto-complete: opt -d,--destination-timezone value Destination IANA time zone
# linto-complete: arg 1 value
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/timezone.py" "$@"
