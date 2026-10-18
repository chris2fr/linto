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
  document)
    usage_name=setup-document.sh
    description='Create a Quarto document from the chris2fr/quarto/document template.'
    ;;
  lettre)
    usage_name=setup-lettre.sh
    description='Create a Quarto document from the chris2fr/quarto/lettre template.'
    ;;
  *) echo "error: unsupported setup template: $name" >&2; exit 2 ;;
esac

case "$help_arg" in
  -h|--help)
    printf 'Usage: %s [-h|--help]\n\n%s\n' "$usage_name" "$description"
    exit 0
    ;;
  '') ;;
  *)
    printf 'Usage: %s [-h|--help]\n' "$usage_name" >&2
    exit 2
    ;;
esac

exec quarto use template "$template"
