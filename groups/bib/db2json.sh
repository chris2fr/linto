#!/bin/sh
# linto-complete: opt -o,--output *.json Output file (default: stdout)
# linto-complete: arg 1 *.db
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o FICHIER.json] [--] <entrée.db>

Exporte la table SQLite « pieces » en JSON.

Options :
  -o, --output FICHIER  Écrit le résultat dans FICHIER (défaut : stdout).
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
[ "$#" -eq 1 ] || die_usage "un seul fichier SQLite est attendu"
input=$1

from_stdin=0
require_file "fichier SQLite" "$input"
[ -n "$output" ] || output=-
[ "$output" = - ] || [ ! "$input" -ef "$output" ] || die_usage "entrée et sortie sont le même fichier"

exec python3 "$script_dir/lib/db2json.py" "$input" "$output"
