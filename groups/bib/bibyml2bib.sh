#!/bin/sh
# linto-complete: opt -o,--output *.bib Output BibTeX file (default: stdout)
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.yml,*.yaml
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o FICHIER.bib] [--] <source.bib>|- <correspondance.yml>
       linto bib $prog

Construit un fichier BibTeX numéroté à partir d'une source BibTeX (ou stdin avec
« - ») et d'une correspondance YAML clé -> numéro.

Sans argument, traite chaque _pieces-*.yml du répertoire courant avec fr.bib et
écrit pieces-*.bib (flux utilisé par « linto render »).

Options :
  -o, --output FICHIER  Écrit le BibTeX dans FICHIER (défaut : stdout).
  -h, --help            Affiche cette aide et quitte.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

generator="$script_dir/lib/generer-bib.py"

# Flux historique par lots, utilisé par le rendu Quarto.
if [ "$#" -eq 0 ]; then
  found=0
  for yml_file in _pieces-*.yml; do
    [ -f "$yml_file" ] || continue
    found=1
    output_base="${yml_file#_}"
    output_base="${output_base%.yml}"
    echo "$yml_file"
    python3 "$generator" fr.bib "$yml_file" --output "$output_base.bib"
  done
  [ "$found" -eq 1 ] || die "aucun fichier _pieces-*.yml; fournir <source.bib> <correspondance.yml>"
  exit 0
fi

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
[ "$#" -eq 2 ] || die_usage "deux arguments sont attendus : source.bib (ou -) et correspondance.yml"
input=$1
yml=$2

resolve_input "fichier BibTeX"
require_file "fichier YAML" "$yml"
if [ -n "$output" ] && [ "$output" != - ]; then
  exec python3 "$generator" "$input" "$yml" --output "$output"
fi
exec python3 "$generator" "$input" "$yml"
