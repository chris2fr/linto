#!/bin/sh
# linto-complete: opt -o,--output *.json Output JSON file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the JSON file in place (-i.bak keeps a backup)
# linto-complete: arg 1 *.json
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o FICHIER.json | -i[.bak]] [--] [<entrée.json>|-]

Remonte d'un cran les champs de "bibtex" et de "frontmatter" au niveau de
l'entrée. Égaux, ou présents d'un seul côté : le champ monte tel quel.
Présents des deux côtés avec des valeurs différentes : la valeur du
frontmatter monte, celle du bibtex reste dans "bibtex" (surcharge).
Les objets "frontmatter" (vidé) et "bibtex" (sans surcharge) disparaissent.

Sans fichier d'entrée (ou avec « - »), lit stdin. Le bilan va sur stderr.

Options :
  -o, --output FICHIER  Écrit le résultat dans FICHIER (défaut : stdout).
  -i                    Remplace le JSON d'entrée.
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
[ "$#" -le 1 ] || die_usage "un seul fichier JSON est attendu"
input=${1-}

resolve_input "fichier JSON"
check_inplace

if [ "$in_place" -eq 1 ]; then
  inplace_begin "$input"
  python3 "$script_dir/lib/lift.py" "$input" "$output_tmp"
  inplace_commit "$input" "$backup_suffix"
else
  [ -n "$output" ] || output=-
  [ "$from_stdin" -eq 1 ] || [ "$output" = - ] || [ ! "$input" -ef "$output" ] ||
    die_usage "entrée et sortie sont le même fichier; utilisez -i"
  exec python3 "$script_dir/lib/lift.py" "$input" "$output"
fi
