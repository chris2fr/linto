#!/bin/sh
# linto-complete: none
# Open the GitHub repository of the Quarto extension this installation uses.
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto quarto github [-h|--help]

Open the Quarto GitHub repository of the extension used in this Linto
installation.

Options:
  -h, --help  Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/../../lib/common.sh"

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  -?*) die_usage "unknown option: %s" "$1" ;;
  *) die_usage "unexpected argument: %s" "$1" ;;
esac

repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
quarto_extension=$(python3 "$repo_dir/lib/config.py" "$repo_dir/config.yml" quarto-extension) ||
  die "cannot read the Quarto extension from the configuration"

exec xdg-open "https://github.com/$quarto_extension"
