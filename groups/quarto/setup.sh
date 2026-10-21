#!/bin/sh
# linto-complete: none
# Add or update the chris2fr/quarto extension in the nearest project.
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto quarto setup [-h|--help]

Find the nearest ancestor containing _extensions/. If it contains
_extensions/chris2fr, update chris2fr/quarto there; otherwise add it there.
If no ancestor contains _extensions/, add chris2fr/quarto from the current
directory.

Options:
  -h, --help  Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/../bib/lib/common.sh"

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  -?*) die_usage "unknown option: %s" "$1" ;;
  *) die_usage "unexpected argument: %s" "$1" ;;
esac
require_cmd quarto

search_dir=$(pwd -P)
extensions_dir=
while :; do
  if [ -d "$search_dir/_extensions" ]; then
    extensions_dir="$search_dir/_extensions"
    break
  fi
  [ "$search_dir" = / ] && break
  search_dir=$(dirname -- "$search_dir")
done

if [ -z "$extensions_dir" ]; then
  exec quarto add chris2fr/quarto
fi

project_dir=$(dirname -- "$extensions_dir")
cd "$project_dir"
if [ -d "$extensions_dir/chris2fr" ]; then
  exec quarto update chris2fr/quarto
else
  exec quarto add chris2fr/quarto
fi
