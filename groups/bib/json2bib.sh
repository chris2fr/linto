#!/bin/sh
# linto-complete: opt -o,--output *.bib Output BibTeX file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the JSON file in place (-i.bak keeps a backup)
# linto-complete: arg 1 *.json
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o FICHIER.bib | -i[.bak]] [--] [<entrée.json>|-]

Reconstruit un fichier BibTeX à partir du JSON : champs BibTeX de premier
niveau (ENTRYTYPE compris), remplacés par les surcharges du champ bibtex
(null supprime le champ). La clé de chaque entrée BibTeX est le nom de sa
propriété dans le JSON.

Sans fichier d'entrée (ou avec « - »), lit stdin.

Options :
  -o, --output FICHIER  Écrit le BibTeX dans FICHIER (défaut : stdout).
  -i                    Remplace le JSON d'entrée par le BibTeX.
  -i.bak                Comme -i, en conservant une copie dans <entrée.json>.bak.
  -h, --help            Affiche cette aide et quitte.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

in_place=0
backup_suffix=
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -i) in_place=1; shift ;;
    -i.bak) in_place=1; backup_suffix=.bak; shift ;;
    -o|--output)
      [ "$#" -ge 2 ] || die_usage "l'option $1 requiert un argument"
      output=$2
      shift 2
      ;;
    --output=*) output=${1#*=}; shift ;;
    -o?*) output=${1#-o}; shift ;;
    --) shift; break ;;
    -?*) die_usage "option inconnue : $1" ;;
    *) break ;;
  esac
done
[ "$#" -le 1 ] || die_usage "au plus un fichier JSON est attendu"
input=${1-}

resolve_input "fichier JSON"
check_inplace

if [ "$in_place" -eq 1 ]; then
  inplace_begin "$input"
  python3 "$script_dir/lib/json2bib.py" "$input" > "$output_tmp"
  inplace_commit "$input" "$backup_suffix"
else
  redirect_output
  exec python3 "$script_dir/lib/json2bib.py" "$input"
fi
