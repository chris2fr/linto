#!/bin/sh
# linto-complete: arg 1 *.db
# linto-complete: arg 2 *.bib
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [--] <entrée.db> <sortie.bib>

Exporte la table SQLite « pieces » en BibTeX.

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
[ "$#" -eq 2 ] || die_usage "deux arguments sont attendus : entrée.db et sortie.bib"
require_file "fichier SQLite" "$1"

exec python3 "$script_dir/lib/db2bib.py" "$1" "$2"
