#!/bin/sh
# linto-complete: opt -o,--output *.db Output database (required)
# linto-complete: arg 1 *.json
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] -o SORTIE.db [--] [<entrée.json>|-]

Construit une base SQLite à partir de la bibliographie JSON. Un fichier de
sortie existant est remplacé. Sans fichier d'entrée (ou avec « - »), lit stdin.

Options :
  -o, --output FICHIER  Base SQLite à écrire (requis : une base ne s'écrit pas
                        sur stdout).
  -h, --help            Affiche cette aide et quitte.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
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
[ -n "$output" ] && [ "$output" != - ] || die_usage "-o/--output est requis"
[ "$from_stdin" -eq 1 ] || [ ! "$input" -ef "$output" ] || die_usage "entrée et sortie sont le même fichier"

exec python3 "$script_dir/lib/json2db.py" "$input" "$output"
