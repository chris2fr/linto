#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec "$script_dir/setup/template.sh" lettre chris2fr/quarto/lettre "$@"
