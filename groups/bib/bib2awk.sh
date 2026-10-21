#!/bin/sh
# linto-complete: opt -t,--theme value Keep entries whose keywords match
# linto-complete: opt -f,--format choices:csv,sed,bibs Output handler
# linto-complete: arg 1 *.bib
set -eu

usage() {
  cat <<'EOF'
Usage: bib2awk.sh [-t THEME] [-f FORMAT] [--] FILE.bib

Extract BibTeX fields using the selected output handler:
  csv   semicolon-separated CSV (default)
  sed   shell commands for replacing howpublished with publisher
  bibs  write one JSON file per entry under ./bib/

Options:
  -t, --theme THEME   Keep entries whose keywords match THEME (comma-separated).
  -f, --format FORMAT Select a handler name (csv, sed, bibs), or a legacy number (1, 2, 3).
  -h, --help          Show this help and exit.

Formats 1 and 2 write to standard output. Format 3 writes JSON files in the
current directory. GNU awk (gawk) is required.
EOF
}

fail() {
  printf 'bib2awk: %s\n' "$*" >&2
  exit 1
}

theme=
format=1
input=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -t|--theme)
      [ "$#" -ge 2 ] || { echo 'bib2awk: --theme requires a value' >&2; exit 2; }
      theme=$2
      shift 2
      ;;
    --theme=*)
      theme=${1#*=}
      shift
      ;;
    -f|--format)
      [ "$#" -ge 2 ] || { echo 'bib2awk: --format requires a value' >&2; exit 2; }
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
        [ -z "$input" ] || { echo 'bib2awk: only one input file may be supplied' >&2; exit 2; }
        input=$1
        shift
      done
      ;;
    -* )
      printf 'bib2awk: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      [ -z "$input" ] || { echo 'bib2awk: only one input file may be supplied' >&2; exit 2; }
      input=$1
      shift
      ;;
  esac
done

[ -n "$input" ] || { usage >&2; exit 2; }
[ -f "$input" ] && [ -r "$input" ] || fail "input file absent or unreadable: $input"
case "$format" in
  1|csv) format=csv ;;
  2|sed) format=sed ;;
  3|bibs) format=bibs ;;
  *) printf 'bib2awk: invalid format: %s\n' "$format" >&2; exit 2 ;;
esac
command -v gawk >/dev/null 2>&1 || fail 'GNU awk (gawk) is required'

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
lib_dir="$script_dir/lib"
awk_file="$lib_dir/bib2awk/$format.awk"
[ -r "$lib_dir/bib2awk.awk" ] || fail "AWK parser not found: $lib_dir/bib2awk.awk"
[ -r "$awk_file" ] || fail "unknown or unreadable output format: $format ($awk_file)"
input_path=$(CDPATH= cd -- "$(dirname -- "$input")" && pwd -P)/$(basename -- "$input")
cd "$lib_dir"
if [ "$format" = bibs ]; then
  mkdir -p ./bib
fi
exec gawk -v theme="$theme" \
  -f bib2awk.awk \
  -f "$awk_file" \
  -- "$input_path"
