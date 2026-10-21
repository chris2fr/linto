#!/bin/sh
# linto-complete: opt -o,--output *.bib Output file (default: stdout)
# linto-complete: arg 1 *.db
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib db2bib [-h|--help] [-o FILE.bib] [--] <input.db>

Export the SQLite "pieces" table to BibTeX.

Options:
  -o, --output FILE  Write the result to FILE (default: stdout).
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
[ "$#" -eq 1 ] || die_usage "exactly one %s is expected" "$(_ "SQLite file")"
input=$1

from_stdin=0
require_file "SQLite file" "$input"
[ -n "$output" ] || output=-
[ "$output" = - ] || [ ! "$input" -ef "$output" ] || die_usage "input and output are the same file"

exec python3 "$script_dir/lib/db2bib.py" "$input" "$output"
