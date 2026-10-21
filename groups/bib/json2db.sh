#!/bin/sh
# linto-complete: arg 1 *.json
# linto-complete: arg 2 *.db
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [--] <entrée.json> <sortie.db>

Construit une base SQLite à partir de la bibliographie JSON. Un fichier de
sortie existant est remplacé.

Options :
  -h, --help   Affiche cette aide et quitte.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -?*) die_usage "option inconnue : $1" ;;
    *) break ;;
  esac
done
[ "$#" -eq 2 ] || die_usage "deux arguments sont attendus : entrée.json et sortie.db"
require_file "fichier JSON" "$1"

exec python3 "$script_dir/lib/json2db.py" "$1" "$2"
