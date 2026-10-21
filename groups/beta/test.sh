#!/bin/sh
# linto-complete: none
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto beta test [-h|--help]

Print "Beta Test". Used to check that the beta group is wired up.

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

printf '%s\n' 'Beta Test'
