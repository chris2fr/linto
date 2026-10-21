#!/bin/sh
# linto-complete: arg 1 *.json
# linto-complete: arg 2 *.db
set -eu

usage() {
  cat <<'EOF'
Usage: json2db.sh <entrée.json> <sortie.db>

Build a SQLite database from the JSON bibliography. An existing output
file will be replaced.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
esac
[ "$#" -eq 2 ] || { usage >&2; exit 2; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/json2db.py" "$1" "$2"
