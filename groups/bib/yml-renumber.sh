#!/bin/sh
# linto-complete: opt -o,--output *.yml,*.yaml Output file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the YAML file in place (-i.bak keeps a backup)
# linto-complete: arg 1 *.yml,*.yaml
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o FICHIER | -i[.bak]] [--] [<entrée.yml>|-]

Renumérote les entrées YAML pour que chaque valeur égale son numéro de ligne.
Sans fichier d'entrée (ou avec « - »), lit stdin.

Options :
  -o, --output FICHIER  Écrit le résultat dans FICHIER (défaut : stdout).
  -i                    Remplace le fichier d'entrée.
  -i.bak                Comme -i, en conservant une copie dans <entrée.yml>.bak.
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
[ "$#" -le 1 ] || die_usage "un seul fichier YAML est attendu"
input=${1-}

resolve_input "fichier YAML"
check_inplace

if [ "$in_place" -eq 1 ]; then
  inplace_begin "$input"
  python3 "$script_dir/lib/renumberyml.py" "$input" "$output_tmp"
  inplace_commit "$input" "$backup_suffix"
else
  [ "$from_stdin" -eq 1 ] || [ -z "$output" ] || [ "$output" = - ] || [ ! "$input" -ef "$output" ] ||
    die_usage "entrée et sortie sont le même fichier; utilisez -i"
  case "$output" in
    ''|-) exec python3 "$script_dir/lib/renumberyml.py" "$input" ;;
    *) exec python3 "$script_dir/lib/renumberyml.py" "$input" "$output" ;;
  esac
fi
