#!/bin/sh
# linto-complete: opt -o,--output *.qmd,*.md Output file (default: stdout)
# linto-complete: opt -f,--format choices:1,2,3 Output layout
# linto-complete: arg 1 *.csv
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o FICHIER] [-f FORMAT] [--] [<fichier.csv>|-]

Convertit des données bibliographiques CSV (séparées par des points-virgules)
en annexe Markdown avec lib/csv2qmd.awk. Le premier enregistrement doit être
l'en-tête attendu par le script AWK.

Sans fichier d'entrée (ou avec « - »), lit stdin.

Options :
  -o, --output FICHIER  Écrit l'annexe dans FICHIER (défaut : stdout).
  -f, --format FORMAT   Disposition de sortie 1, 2 ou 3 (défaut : 1).
  -h, --help            Affiche cette aide et quitte.

GNU awk (gawk) est requis.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

format=1
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -f|--format)
      [ "$#" -ge 2 ] || die_usage "l'option $1 requiert un argument"
      format=$2
      shift 2
      ;;
    --format=*) format=${1#*=}; shift ;;
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
[ "$#" -le 1 ] || die_usage "un seul fichier CSV est attendu"
input=${1-}

resolve_input "fichier CSV"
case "$format" in
  1|2|3) ;;
  *) die_usage "format invalide : $format (attendu : 1, 2 ou 3)" ;;
esac
require_cmd gawk

awk_file="$script_dir/lib/csv2qmd.awk"
[ -r "$awk_file" ] || die "programme AWK introuvable : $awk_file"

redirect_output
exec gawk -v output_format="$format" -f "$awk_file" -- "$input"
