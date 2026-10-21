#!/bin/sh
# linto-complete: opt -o,--output *.json Output JSON file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the existing JSON in place (-i.bak keeps a backup)
# linto-complete: flag --as-override Store a modified, non-overridden field as a "bibtex" override
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.json
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib bib2json [-h|--help] [-o FILE.json | -i[.bak]] [--as-override]
          [--] [<file.bib>|-] [<existing.json>]

Propagate BibTeX entries to the existing JSON keys and create a key for each
BibTeX entry missing from the JSON (top-level fields). Field already overridden
in "bibtex": the override is updated; otherwise the top-level value is updated;
field gone from the BibTeX: null override.
Each record starts with "key", which repeats the name of its property.

Without a BibTeX file (or with "-"), read stdin. Without an existing JSON, start
from an empty JSON: every BibTeX entry is created.

Options:
  -o, --output FILE  Write the result to FILE. By default (or with "-o -"), the
                     result goes to stdout and the list of created keys to
                     stderr.
  -i                 Replace the existing JSON (required; incompatible with -o).
  -i.bak             Like -i, keeping a copy in <existing.json>.bak.
  --as-override      A value changed in the BibTeX, for a field with no override
                     yet, becomes a "bibtex" override (the top-level value is
                     kept).
  -h, --help         Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/lib/common.sh"

in_place=0
as_override=
backup_suffix=
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --as-override) as_override=1; shift ;;
    -i) in_place=1; shift ;;
    -i.bak) in_place=1; backup_suffix=.bak; shift ;;
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
[ "$#" -le 2 ] || die_usage "at most two arguments are expected: file.bib and existing.json"
input=${1-}
json_in=${2-}

resolve_input "fichier BibTeX"
[ -z "$json_in" ] || require_file "JSON file" "$json_in"
[ "$output" != - ] || output=
if [ "$in_place" -eq 1 ]; then
  [ -n "$json_in" ] || die_usage "-i needs an existing JSON file as the second argument"
  [ -z "$output" ] || die_usage "-i and -o/--output are incompatible"
  inplace_begin "$json_in"
  output=$output_tmp
elif [ -n "$json_in" ] && [ -n "$output" ] && [ "$json_in" -ef "$output" ]; then
  die_usage "input and output JSON are the same file; use -i"
fi

# prérequis, une seule fois : python3 -m pip install bibtexparser
python3 "$script_dir/lib/bib2json.py" "$input" "$json_in" "$output" "$as_override"

if [ "$in_place" -eq 1 ]; then
  inplace_commit "$json_in" "$backup_suffix"
fi
