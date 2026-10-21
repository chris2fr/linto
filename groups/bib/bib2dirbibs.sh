#!/bin/sh
# linto-complete: opt -o,--output dir Output directory (default: ./bib)
# linto-complete: arg 1 *.bib
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o RÉPERTOIRE] [--] [<fichier.bib>|-]

Éclate un fichier BibTeX en un fichier par entrée, RÉPERTOIRE/<clé>.bib
(le répertoire est créé au besoin) avec lib/mkbib.awk.

Sans fichier d'entrée (ou avec « - »), lit stdin.

Options :
  -o, --output RÉPERTOIRE  Répertoire de sortie (défaut : ./bib).
  -h, --help               Affiche cette aide et quitte.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

output=./bib
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
[ "$#" -le 1 ] || die_usage "un seul fichier BibTeX est attendu"
input=${1-}

resolve_input "fichier BibTeX"
[ -n "$output" ] || die_usage "le répertoire de sortie est vide"
[ ! -e "$output" ] || [ -d "$output" ] || die "n'est pas un répertoire : $output"

mkdir -p -- "$output"
exec awk -v outdir="${output%/}" -f "$script_dir/lib/mkbib.awk" "$input"
