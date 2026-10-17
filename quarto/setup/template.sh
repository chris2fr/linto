#!/bin/sh
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "error: internal setup-template invocation is malformed" >&2
  exit 2
fi

name=$1
template=$2
help_arg=${3-}

case "$name" in
  document) description='Create a Quarto document from the chris2fr/quarto/document template.' ;;
  lettre) description='Create a Quarto document from the chris2fr/quarto/lettre template.' ;;
  *) echo "error: unsupported setup template: $name" >&2; exit 2 ;;
esac

case "$help_arg" in
  -h|--help)
    printf 'Usage: setup-%s.sh [-h|--help]\n\n%s\n' "$name" "$description"
    exit 0
    ;;
  '') ;;
  *)
    printf 'Usage: setup-%s.sh [-h|--help]\n' "$name" >&2
    exit 2
    ;;
esac

exec quarto use template "$template"
