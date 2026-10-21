#!/bin/sh
# linto-complete: opt -o,--output *.qmd,*.md Output file (default: stdout)
# linto-complete: opt -f,--format choices:1,2,3 Output layout
# linto-complete: arg 1 *.csv
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib csv2qmd [-h|--help] [-o FILE] [-f FORMAT] [--] [<file.csv>|-]

Convert semicolon-separated bibliography data into a Markdown annex with
lib/csv2qmd.awk. The first record must be the header expected by the AWK
script.

Without an input file (or with "-"), read stdin.

Options:
  -o, --output FILE   Write the annex to FILE (default: stdout).
  -f, --format FORMAT Output layout 1, 2 or 3 (default: 1).
  -h, --help          Show this help and exit.

GNU awk (gawk) is required.
EOF
)"
  echo
}

. "$(dirname -- "$0")/lib/common.sh"

format=1
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -f|--format)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      format=$2
      shift 2
      ;;
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
[ "$#" -le 1 ] || die_usage "exactly one %s is expected" "$(_ "CSV file")"
input=${1-}

resolve_input "fichier CSV"
case "$format" in
  1|2|3) ;;
  *) die_usage "invalid format: %s (expected 1, 2 or 3)" "$format" ;;
esac
require_cmd gawk

awk_file="$script_dir/lib/csv2qmd.awk"
[ -r "$awk_file" ] || die "AWK program not found: %s" "$awk_file"

redirect_output
exec gawk -v output_format="$format" -f "$awk_file" -- "$input"
