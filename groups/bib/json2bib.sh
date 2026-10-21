#!/bin/sh
# linto-complete: flag -i,-i.bak Replace the JSON file in place (-i.bak keeps a backup)
# linto-complete: arg 1 *.json
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-i[.bak]] [--] <entrée.json>

Reconstruit un fichier BibTeX à partir du JSON : champs BibTeX de premier
niveau (ENTRYTYPE compris), remplacés par les surcharges du champ bibtex
(null supprime le champ). La clé de chaque entrée BibTeX est le nom de sa
propriété dans le JSON.

Options :
  -i           Remplace le JSON d'entrée par le BibTeX.
  -i.bak       Comme -i, en conservant une copie dans <entrée.json>.bak.
  -h, --help   Affiche cette aide et quitte.

Par défaut, le résultat est écrit sur stdout.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

in_place=0
backup_suffix=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -i) in_place=1; shift ;;
    -i.bak) in_place=1; backup_suffix=.bak; shift ;;
    --) shift; break ;;
    -?*) die_usage "option inconnue : $1" ;;
    *) break ;;
  esac
done
[ "$#" -eq 1 ] || die_usage "un seul fichier JSON est attendu"

json_in=$1
require_file "fichier JSON" "$json_in"

if [ "$in_place" -eq 1 ]; then
  inplace_begin "$json_in"
  python3 "$script_dir/lib/json2bib.py" "$json_in" > "$output_tmp"
  inplace_commit "$json_in" "$backup_suffix"
else
  python3 "$script_dir/lib/json2bib.py" "$json_in"
fi
