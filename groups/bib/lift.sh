#!/bin/sh
# linto-complete: arg 1 *.json
# linto-complete: arg 2 *.json
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [--] <entrée.json> <sortie.json>

Remonte d'un cran les champs de "bibtex" et de "frontmatter" au niveau de
l'entrée. Égaux, ou présents d'un seul côté : le champ monte tel quel.
Présents des deux côtés avec des valeurs différentes : la valeur du
frontmatter monte, celle du bibtex reste dans "bibtex" (surcharge).
Les objets "frontmatter" (vidé) et "bibtex" (sans surcharge) disparaissent.

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
[ "$#" -eq 2 ] || die_usage "deux arguments sont attendus : entrée.json et sortie.json"
require_file "fichier JSON" "$1"

exec python3 "$script_dir/lib/lift.py" "$1" "$2"
