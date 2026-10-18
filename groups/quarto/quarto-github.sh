#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
Usage: quarto-github.sh

Opens the Quarto GitHub repository of the extension used in this linto installation
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; exit 2 ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
config_file="$repo_dir/config.yml"

config_helper="$repo_dir/lib/config.py"
if ! quarto_extension=$(python3 "$config_helper" "$config_file" quarto-extension); then
  exit 1
fi

exec xdg-open "https://github.com/$quarto_extension"
