#!/bin/sh
# linto-complete: arg * *.png,*.jpg,*.jpeg,*.gif,*.bmp,*.webp
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/qrcode_cmd.py" decode "$@"
