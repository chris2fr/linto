#!/bin/sh
# linto-complete: opt -o,--output *.db Output database (required)
# linto-complete: arg 1 *.json
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib json2db [-h|--help] -o OUTPUT.db [--] [<input.json>|-]

Build a SQLite database from the JSON bibliography. An existing output file is
replaced. Without an input file (or with "-"), read stdin.

Options:
  -o, --output FILE  SQLite database to write (required: a database cannot be
                     written to stdout).
  -h, --help         Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/lib/common.sh"

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
[ "$#" -le 1 ] || die_usage "exactly one %s is expected" "$(_ "JSON file")"
input=${1-}

resolve_input "fichier JSON"
[ -n "$output" ] && [ "$output" != - ] || die_usage "-o/--output is required"
[ "$from_stdin" -eq 1 ] || [ ! "$input" -ef "$output" ] || die_usage "input and output are the same file"

exec python3 "$script_dir/lib/json2db.py" "$input" "$output"
