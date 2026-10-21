#!/bin/sh
# linto-complete: flag -s,--sort Sort the properties alphabetically
# linto-complete: arg 1 *.json
set -eu

usage() {
  cat <<USAGE
Usage: $0 [-h|--help] [-s|--sort] [<fichier.json>]

Liste les propriétés de premier niveau d'un fichier JSON, une par ligne, dans
l'ordre du fichier. Sans fichier (ou avec « - »), lit stdin.

Options :
  -s, --sort   Trie les propriétés par ordre alphabétique.
  -h, --help   Affiche cette aide et quitte.
USAGE
}

keys='keys_unsorted'
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -s|--sort) keys='keys'; shift ;;
    --) shift; break ;;
    -?*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
    *) break ;;
  esac
done
[ "$#" -le 1 ] || { usage >&2; exit 2; }

input=${1--}
if [ "$input" != - ]; then
  [ -f "$input" ] && [ -r "$input" ] || {
    echo "$0: fichier JSON absent ou illisible : $input" >&2
    exit 1
  }
fi

filter="if type == \"object\" then $keys[] else error(\"le JSON doit être un objet\") end"
if [ "$input" = - ]; then
  exec jq -r "$filter"
fi
exec jq -r "$filter" "$input"
