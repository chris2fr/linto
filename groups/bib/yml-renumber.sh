#!/bin/sh
# linto-complete: opt -o,--output *.yml,*.yaml Output file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the YAML file in place (-i.bak keeps a backup)
# linto-complete: arg 1 *.yml,*.yaml
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib yml-renumber [-h|--help] [-o FILE | -i[.bak]] [--] [<input.yml>|-]

Renumber the YAML entries so that each value equals its line number.
Without an input file (or with "-"), read stdin.

Options:
  -o, --output FILE  Write the result to FILE (default: stdout).
  -i                 Replace the input file.
  -i.bak             Like -i, keeping a copy in <input.yml>.bak.
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
[ "$#" -le 1 ] || die_usage "exactly one %s is expected" "$(_ "YAML file")"
input=${1-}

resolve_input "fichier YAML"
check_inplace

if [ "$in_place" -eq 1 ]; then
  inplace_begin "$input"
  python3 "$script_dir/lib/renumberyml.py" "$input" "$output_tmp"
  inplace_commit "$input" "$backup_suffix"
else
  [ "$from_stdin" -eq 1 ] || [ -z "$output" ] || [ "$output" = - ] || [ ! "$input" -ef "$output" ] ||
    die_usage "input and output are the same file; use -i"
  case "$output" in
    ''|-) exec python3 "$script_dir/lib/renumberyml.py" "$input" ;;
    *) exec python3 "$script_dir/lib/renumberyml.py" "$input" "$output" ;;
  esac
fi
