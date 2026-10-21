#!/bin/sh
# linto-complete: opt -o,--output *.bib Output BibTeX file (default: stdout)
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.yml,*.yaml
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib bibyml2bib [-h|--help] [-o FILE.bib] [--] <source.bib>|- <mapping.yml>
       linto bib bibyml2bib

Build a numbered BibTeX file from a BibTeX source (or stdin with "-") and a
YAML key -> number mapping.

With no arguments, process each _pieces-*.yml of the current directory with
fr.bib and write pieces-*.bib (the flow used by "linto render").

Options:
  -o, --output FILE  Write the BibTeX to FILE (default: stdout).
  -h, --help         Show this help and exit.
EOF
)"
  echo
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
  [ "$found" -eq 1 ] || die "no _pieces-*.yml file; give <source.bib> <mapping.yml>"
  exit 0
fi

output=
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
[ "$#" -eq 2 ] || die_usage "two arguments are expected: source.bib (or -) and mapping.yml"
input=$1
yml=$2

resolve_input "fichier BibTeX"
require_file "YAML file" "$yml"
if [ -n "$output" ] && [ "$output" != - ]; then
  exec python3 "$generator" "$input" "$yml" --output "$output"
fi
exec python3 "$generator" "$input" "$yml"
