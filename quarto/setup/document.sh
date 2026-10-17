#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: document.sh [-h|--help]

Create a Quarto document from the chris2fr/quarto/document template in the
current directory.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; exit 2 ;;
esac

exec quarto use template chris2fr/quarto/document
