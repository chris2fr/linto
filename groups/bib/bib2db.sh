#!/bin/sh
# linto-complete: opt -o,--output *.db Output database (requires --apply)
# linto-complete: flag --apply Write the changes (default: dry run)
# linto-complete: flag --prune Delete database entries absent from the BibTeX file
# linto-complete: flag --as-override Store a modified, non-overridden field as a "bibtex" override
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.db
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib bib2db [-h|--help] [--apply [-o OUTPUT.db]] [--prune]
          [--as-override] [--] <file.bib>|- <file.db>

Compare a BibTeX file with the SQLite "pieces" table. By default, show the
changes field by field on stdout without writing anything.
The BibTeX may come from stdin ("-").

Options:
  --apply             Apply the changes to the .db file.
  -o, --output FILE   With --apply: copy the .db to FILE and apply the changes
                      there; the input .db is left unchanged.
  --prune             Delete the rows whose key is absent from the BibTeX.
  --as-override       A value changed in the BibTeX, for a field with no
                      override yet, becomes a "bibtex" override (the base value
                      is kept; by default it replaces the base value).
  -h, --help          Show this help and exit.

A field removed from the BibTeX gets a null override (its base value is kept).
A field unknown to the schema also becomes an override.
EOF
)"
  echo
}

. "$(dirname -- "$0")/lib/common.sh"

flags=
apply=0
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --apply) apply=1; flags="$flags $1"; shift ;;
    --prune|--as-override) flags="$flags $1"; shift ;;
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
[ "$#" -eq 2 ] || die_usage "two arguments are expected: file.bib (or -) and file.db"
input=$1
db=$2

resolve_input "fichier BibTeX"
require_file "SQLite file" "$db"
target=$db
if [ -n "$output" ]; then
  [ "$apply" -eq 1 ] || die_usage "-o/--output needs --apply"
  [ ! "$db" -ef "$output" ] || die_usage "input and output are the same file"
  cp -- "$db" "$output"
  target=$output
fi

# shellcheck disable=SC2086
exec python3 "$script_dir/lib/bib2db.py" "$input" "$target" $flags
