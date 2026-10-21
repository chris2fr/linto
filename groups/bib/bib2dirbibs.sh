#!/bin/sh
# linto-complete: arg 1 *.bib
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [--] <fichier.bib>

Éclate un fichier BibTeX en un fichier par entrée dans ./bib/<clé>.bib
(le répertoire est créé au besoin) avec lib/mkbib.awk.

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
[ "$#" -eq 1 ] || die_usage "un seul fichier BibTeX est attendu"
require_file "fichier BibTeX" "$1"

mkdir -p ./bib
exec awk -f "$script_dir/lib/mkbib.awk" "$1"
