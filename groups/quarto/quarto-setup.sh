#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: quarto-setup.sh [-h|--help]

Find the nearest ancestor containing _extensions/. If it contains
_extensions/chris2fr, update chris2fr/quarto there; otherwise add it there.
If no ancestor contains _extensions/, add chris2fr/quarto from the current
directory.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; exit 2 ;;
esac

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
