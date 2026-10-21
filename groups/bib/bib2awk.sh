#!/bin/sh
# linto-complete: opt -o,--output value Output file (csv, sed) or directory (bibs; default: ./bib)
# linto-complete: opt -t,--theme value Keep entries whose keywords match
# linto-complete: opt -f,--format choices:csv,sed,bibs Output handler
# linto-complete: arg 1 *.bib
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o SORTIE] [-t THÈME] [-f FORMAT] [--]
          [<fichier.bib>|-]

Extrait les champs BibTeX avec le gestionnaire de sortie choisi :
  csv   CSV séparé par des points-virgules (défaut)
  sed   commandes shell remplaçant howpublished par publisher
  bibs  un fichier JSON par entrée

Sans fichier d'entrée (ou avec « - »), lit stdin.

Options :
  -o, --output SORTIE   csv et sed : fichier de sortie (défaut : stdout).
                        bibs : répertoire de sortie (défaut : ./bib).
  -t, --theme THÈME     Garde les entrées dont les mots-clés correspondent à
                        THÈME (séparés par des virgules).
  -f, --format FORMAT   Nom du gestionnaire (csv, sed, bibs) ou ancien numéro
                        (1, 2, 3).
  -h, --help            Affiche cette aide et quitte.

GNU awk (gawk) est requis.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

theme=
format=1
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -t|--theme|-f|--format)
      [ "$#" -ge 2 ] || die_usage "l'option $1 requiert un argument"
      case "$1" in -t|--theme) theme=$2 ;; *) format=$2 ;; esac
      shift 2
      ;;
    --theme=*) theme=${1#*=}; shift ;;
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
[ "$#" -le 1 ] || die_usage "un seul fichier BibTeX est attendu"
input=${1-}

resolve_input "fichier BibTeX"
case "$format" in
  1|csv) format=csv ;;
  2|sed) format=sed ;;
  3|bibs) format=bibs ;;
  *) die_usage "format invalide : $format (attendu : csv, sed ou bibs)" ;;
esac
require_cmd gawk

lib_dir="$script_dir/lib"
awk_file="$lib_dir/bib2awk/$format.awk"
[ -r "$lib_dir/bib2awk.awk" ] || die "analyseur AWK introuvable : $lib_dir/bib2awk.awk"
[ -r "$awk_file" ] || die "format de sortie inconnu ou illisible : $format ($awk_file)"

outdir=
if [ "$format" = bibs ]; then
  outdir=${output:-./bib}
  [ ! -e "$outdir" ] || [ -d "$outdir" ] || die "n'est pas un répertoire : $outdir"
  mkdir -p -- "$outdir"
else
  redirect_output
fi
exec gawk -v theme="$theme" -v outdir="${outdir%/}" \
  -f "$lib_dir/bib2awk.awk" \
  -f "$awk_file" \
  -- "$input"
