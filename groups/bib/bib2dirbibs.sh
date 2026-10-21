#!/bin/sh
# linto-complete: opt -o,--output dir Output directory (default: ./bib)
# linto-complete: arg 1 *.bib
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib bib2dirbibs [-h|--help] [-o DIR] [--] [<file.bib>|-]

Split a BibTeX file into one file per entry, DIR/<key>.bib (the directory is
created if needed) with lib/mkbib.awk.

Without an input file (or with "-"), read stdin.

Options:
  -o, --output DIR  Output directory (default: ./bib).
  -h, --help        Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/lib/common.sh"

output=./bib
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
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
[ -n "$output" ] || die_usage "the output directory is empty"
[ ! -e "$output" ] || [ -d "$output" ] || die "not a directory: %s" "$output"

mkdir -p -- "$output"
exec awk -v outdir="${output%/}" -f "$script_dir/lib/mkbib.awk" "$input"
