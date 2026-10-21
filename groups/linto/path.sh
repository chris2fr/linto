#!/bin/sh
# linto-complete: none
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto path [-h|--help]

Print the absolute path to the Linto installation directory.

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

cd -- "$script_dir/../.."
pwd -P
