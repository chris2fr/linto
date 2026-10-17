#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec "$script_dir/setup/template.sh" lettre chris2fr/quarto/lettre "$@"
