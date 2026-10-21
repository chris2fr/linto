#!/bin/sh
# linto-complete: arg 1 *.json
# linto-complete: arg 2 *.json
set -eu

usage() {
  cat <<'EOF2'
Usage: lift.sh <entrée.json> <sortie.json>

Remonte d'un cran les champs de "bibtex" et de "frontmatter" au niveau de
l'entrée. Égaux, ou présents d'un seul côté : le champ monte tel quel.
Présents des deux côtés avec des valeurs différentes : la valeur du
frontmatter monte, celle du bibtex reste dans "bibtex" (surcharge).
Les objets "frontmatter" (vidé) et "bibtex" (sans surcharge) disparaissent.
EOF2
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
esac
[ "$#" -eq 2 ] || { usage >&2; exit 2; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/lift.py" "$1" "$2"
