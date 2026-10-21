#!/bin/sh
# linto-complete: opt -o,--output *.bib Output BibTeX file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the JSON file in place (-i.bak keeps a backup)
# linto-complete: arg 1 *.json
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib json2bib [-h|--help] [-o FILE.bib | -i[.bak]] [--] [<input.json>|-]

Rebuild a BibTeX file from the JSON: top-level BibTeX fields (ENTRYTYPE
included), replaced by the overrides of the bibtex field (null removes the
field). The key of each BibTeX entry is the name of its property in the JSON.

Without an input file (or with "-"), read stdin.

Options:
  -o, --output FILE  Write the BibTeX to FILE (default: stdout).
  -i                 Replace the input JSON with the BibTeX.
  -i.bak             Like -i, keeping a copy in <input.json>.bak.
  -h, --help         Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/lib/common.sh"

in_place=0
backup_suffix=
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
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
[ "$#" -le 1 ] || die_usage "at most one %s is expected" "$(_ "JSON file")"
input=${1-}

resolve_input "fichier JSON"
check_inplace

if [ "$in_place" -eq 1 ]; then
  inplace_begin "$input"
  python3 "$script_dir/lib/json2bib.py" "$input" > "$output_tmp"
  inplace_commit "$input" "$backup_suffix"
else
  redirect_output
  exec python3 "$script_dir/lib/json2bib.py" "$input"
fi
