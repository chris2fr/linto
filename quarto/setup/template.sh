#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  printf 'Usage: %s [-h|--help]\n' "$1" >&2
  exit 2
fi

name=$1
template=$2
argument=$3

case "$name" in
  document)
    description='Create a Quarto document from the chris2fr/quarto/document template.'
    ;;
  lettre)
    description='Create a Quarto document from the chris2fr/quarto/lettre template.'
    ;;
  *)
    printf 'error: unsupported setup template: %s\n' "$name" >&2
    exit 2
    ;;
esac

case "$argument" in
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
