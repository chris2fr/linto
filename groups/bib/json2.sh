#!/bin/sh
# linto-complete: flag -s,--sort Sort the properties alphabetically
# linto-complete: opt -o,--output value Output file (default: stdout)
# linto-complete: arg 1 *.json
set -eu

usage() {
  cat <<USAGE
Usage: linto bib $prog [-h|--help] [-o FICHIER] [-s|--sort] [--] [<fichier.json>|-]

Liste les propriétés de premier niveau d'un fichier JSON, une par ligne, dans
l'ordre du fichier. Sans fichier (ou avec « - »), lit stdin.

Options :
  -o, --output FICHIER  Écrit la liste dans FICHIER (défaut : stdout).
  -s, --sort            Trie les propriétés par ordre alphabétique.
  -h, --help            Affiche cette aide et quitte.
USAGE
}

. "$(dirname -- "$0")/lib/common.sh"

keys='keys_unsorted'
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -s|--sort) keys='keys'; shift ;;
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
require_cmd jq
redirect_output

filter="if type == \"object\" then $keys[] else error(\"le JSON doit être un objet\") end"
exec jq -r "$filter" "$input"
