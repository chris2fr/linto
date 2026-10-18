#!/bin/sh
# linto-complete: none
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec "$script_dir/setup/template.sh" document chris2fr/quarto/document "$@"
