#!/bin/sh
# linto-complete: opt -o,--output value Output file (csv, sed) or directory (bibs; default: ./bib)
# linto-complete: opt -t,--theme value Keep entries whose keywords match
# linto-complete: opt -f,--format choices:csv,sed,bibs Output handler
# linto-complete: arg 1 *.bib
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib bib2awk [-h|--help] [-o OUTPUT] [-t THEME] [-f FORMAT] [--]
          [<file.bib>|-]

Extract BibTeX fields with the chosen output handler:
  csv   semicolon-separated CSV (default)
  sed   shell commands replacing howpublished with publisher
  bibs  one JSON file per entry

Without an input file (or with "-"), read stdin.

Options:
  -o, --output OUTPUT  csv and sed: output file (default: stdout).
                       bibs: output directory (default: ./bib).
  -t, --theme THEME    Keep entries whose keywords match THEME (comma-separated).
  -f, --format FORMAT  Handler name (csv, sed, bibs) or legacy number (1, 2, 3).
  -h, --help           Show this help and exit.

GNU awk (gawk) is required.
EOF
)"
  echo
}

. "$(dirname -- "$0")/lib/common.sh"

theme=
format=1
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -t|--theme|-f|--format)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      case "$1" in -t|--theme) theme=$2 ;; *) format=$2 ;; esac
      shift 2
      ;;
    --theme=*) theme=${1#*=}; shift ;;
    --format=*) format=${1#*=}; shift ;;
    -o|--output)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      output=$2
      shift 2
      ;;
    --output=*) output=${1#*=}; shift ;;
    -o?*) output=${1#-o}; shift ;;
    --) shift; break ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *) break ;;
  esac
done
[ "$#" -le 1 ] || die_usage "exactly one %s is expected" "$(_ "BibTeX file")"
input=${1-}

resolve_input "fichier BibTeX"
case "$format" in
  1|csv) format=csv ;;
  2|sed) format=sed ;;
  3|bibs) format=bibs ;;
  *) die_usage "invalid format: %s (expected csv, sed or bibs)" "$format" ;;
esac
require_cmd gawk

lib_dir="$script_dir/lib"
awk_file="$lib_dir/bib2awk/$format.awk"
[ -r "$lib_dir/bib2awk.awk" ] || die "AWK parser not found: %s" "$lib_dir/bib2awk.awk"
[ -r "$awk_file" ] || die "unknown or unreadable output format: %s (%s)" "$format" "$awk_file"

outdir=
if [ "$format" = bibs ]; then
  outdir=${output:-./bib}
  [ ! -e "$outdir" ] || [ -d "$outdir" ] || die "not a directory: %s" "$outdir"
  mkdir -p -- "$outdir"
else
  redirect_output
fi
exec gawk -v theme="$theme" -v outdir="${outdir%/}" \
  -f "$lib_dir/bib2awk.awk" \
  -f "$awk_file" \
  -- "$input"
