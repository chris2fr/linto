#!/bin/sh
# linto-complete: opt -f,--format choices:1,2,3 Output layout
# linto-complete: arg 1 *.csv
set -eu

usage() {
  cat <<'EOF'
Usage: csv2qmd.sh [-f FORMAT] [--] FILE.csv

Convert semicolon-separated bibliography data to a Markdown annex using
lib/csv2qmd.awk. The first record must be the header expected by the AWK script.

Options:
  -f, --format FORMAT  Select output layout 1, 2, or 3 (default: 1).
  -h, --help           Show this help and exit.

Output is written to standard output. GNU awk (gawk) is required.
EOF
}

fail() {
  printf 'csv2qmd: %s\n' "$*" >&2
  exit 1
}

format=1
input=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -f|--format)
      [ "$#" -ge 2 ] || { echo 'csv2qmd: --format requires a value' >&2; exit 2; }
      format=$2
      shift 2
      ;;
    --format=*)
      format=${1#*=}
      shift
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        [ -z "$input" ] || { echo 'csv2qmd: only one input file may be supplied' >&2; exit 2; }
        input=$1
        shift
      done
      ;;
    -* )
      printf 'csv2qmd: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      [ -z "$input" ] || { echo 'csv2qmd: only one input file may be supplied' >&2; exit 2; }
      input=$1
      shift
      ;;
  esac
done

[ -n "$input" ] || { usage >&2; exit 2; }
[ -f "$input" ] && [ -r "$input" ] || fail "input file absent or unreadable: $input"
case "$format" in
  1|2|3) ;;
  *) printf 'csv2qmd: invalid format: %s (expected 1, 2, or 3)\n' "$format" >&2; exit 2 ;;
esac
command -v gawk >/dev/null 2>&1 || fail 'GNU awk (gawk) is required'

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
awk_file="$script_dir/lib/csv2qmd.awk"
[ -r "$awk_file" ] || fail "AWK program not found: $awk_file"

exec gawk -v output_format="$format" -f "$awk_file" -- "$input"
