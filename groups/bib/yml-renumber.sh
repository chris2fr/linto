#!/bin/sh
# linto-complete: arg 1 *.yml,*.yaml
# linto-complete: arg 2 *.yml,*.yaml
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [--] <entrée.yml> [sortie.yml]

Renumérote les entrées YAML pour que chaque valeur égale son numéro de ligne.
Sans fichier de sortie, le résultat est écrit sur stdout.

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
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || die_usage "un ou deux fichiers sont attendus"
require_file "fichier YAML" "$1"

exec python3 "$script_dir/lib/renumberyml.py" "$@"
