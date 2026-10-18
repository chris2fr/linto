#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
Usage: github.sh

Opens the GitHub repository of linto
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



exec xdg-open "https://github.com/chris2fr/linto"
