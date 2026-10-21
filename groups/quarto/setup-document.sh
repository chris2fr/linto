#!/bin/sh
# linto-complete: none
# Create a Quarto document from the chris2fr/quarto/document template.
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto quarto setup-document [-h|--help]

Create a Quarto document from the chris2fr/quarto/document template.

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
require_cmd quarto

exec quarto use template chris2fr/quarto/document
