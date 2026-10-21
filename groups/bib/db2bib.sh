#!/bin/sh
# linto-complete: arg 1 *.db
# linto-complete: arg 2 *.bib
set -eu

usage() {
  cat <<'EOF'
Usage: db2bib.sh <entrée.db> <sortie.bib>

Export the SQLite pieces table to BibTeX.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
esac
[ "$#" -eq 2 ] || { usage >&2; exit 2; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/db2bib.py" "$1" "$2"
