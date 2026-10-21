#!/bin/sh
# linto-complete: flag -s,--sort Sort the properties alphabetically
# linto-complete: arg 1 *.json
set -eu

usage() {
  cat <<USAGE
Usage: linto bib $prog [-h|--help] [-s|--sort] [--] [<fichier.json>]

Liste les propriétés de premier niveau d'un fichier JSON, une par ligne, dans
l'ordre du fichier. Sans fichier (ou avec « - »), lit stdin.

Options :
  -s, --sort   Trie les propriétés par ordre alphabétique.
  -h, --help   Affiche cette aide et quitte.
USAGE
}

. "$(dirname -- "$0")/lib/common.sh"

keys='keys_unsorted'
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -s|--sort) keys='keys'; shift ;;
    --) shift; break ;;
    -?*) die_usage "option inconnue : $1" ;;
    *) break ;;
  esac
done
[ "$#" -le 1 ] || die_usage "au plus un fichier JSON est attendu"

input=${1--}
if [ "$input" != - ]; then
  require_file "fichier JSON" "$input"
fi

require_cmd jq
filter="if type == \"object\" then $keys[] else error(\"le JSON doit être un objet\") end"
if [ "$input" = - ]; then
  exec jq -r "$filter"
fi
exec jq -r "$filter" "$input"
