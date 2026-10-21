#!/bin/sh
# linto-complete: opt -o,--output *.json Output JSON file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the JSON file in place (-i.bak keeps a backup)
# linto-complete: arg 1 *.json
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib lift [-h|--help] [-o FILE.json | -i[.bak]] [--] [<input.json>|-]

Lift the fields of "bibtex" and "frontmatter" one level up, to the entry.
Equal, or present on one side only: the field is lifted as is.
Present on both sides with different values: the frontmatter value is lifted,
the bibtex one stays in "bibtex" (override).
The "frontmatter" (emptied) and "bibtex" (without override) objects disappear.

Without an input file (or with "-"), read stdin. The summary goes to stderr.

Options:
  -o, --output FILE  Write the result to FILE (default: stdout).
  -i                 Replace the input JSON.
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
[ "$#" -le 1 ] || die_usage "exactly one %s is expected" "$(_ "JSON file")"
input=${1-}

resolve_input "fichier JSON"
check_inplace

if [ "$in_place" -eq 1 ]; then
  inplace_begin "$input"
  python3 "$script_dir/lib/lift.py" "$input" "$output_tmp"
  inplace_commit "$input" "$backup_suffix"
else
  [ -n "$output" ] || output=-
  [ "$from_stdin" -eq 1 ] || [ "$output" = - ] || [ ! "$input" -ef "$output" ] ||
    die_usage "input and output are the same file; use -i"
  exec python3 "$script_dir/lib/lift.py" "$input" "$output"
fi
