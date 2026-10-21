#!/bin/sh
# linto-complete: flag -s,--sort Sort the properties alphabetically
# linto-complete: opt -o,--output value Output file (default: stdout)
# linto-complete: arg 1 *.json
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto bib json2 [-h|--help] [-o FILE] [-s|--sort] [--] [<file.json>|-]

List the top-level properties of a JSON file, one per line, in file order.
Without a file (or with "-"), read stdin.

Options:
  -o, --output FILE  Write the list to FILE (default: stdout).
  -s, --sort         Sort the properties alphabetically.
  -h, --help         Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/lib/common.sh"

keys='keys_unsorted'
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -s|--sort) keys='keys'; shift ;;
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
require_cmd jq
redirect_output

not_object=$(_ "the JSON must be an object")
filter="if type == \"object\" then $keys[] else error(\"$not_object\") end"
exec jq -r "$filter" "$input"
