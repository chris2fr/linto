#!/bin/sh
# linto-complete: none
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto github [-h|--help]

Open the GitHub repository of Linto.

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

exec xdg-open "https://github.com/chris2fr/linto"
