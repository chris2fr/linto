#!/bin/sh
# linto-complete: opt -o,--output *.png,*.svg,*.pdf,*.eps Image file to write (default: qr.png)
# linto-complete: opt -e,--error choices:L,M,Q,H Error correction level
# linto-complete: opt -s,--scale value Pixels per module
# linto-complete: opt --border value Quiet zone in modules
# linto-complete: flag --no-image Print terminal art only
# linto-complete: flag --no-ascii Write the image only
# linto-complete: flag --invert Terminal art for a light background
# linto-complete: flag --force Overwrite an existing image file
# linto-complete: arg * value
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/qrcode_cmd.py" encode "$@"
