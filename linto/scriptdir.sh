#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help)
      printf 'Usage: %s [-h|--help]\n\nPrint the absolute path to the Linto installation directory.\n' "${0##*/}"
      exit 0
      ;;
    *)
      printf 'Usage: %s [-h|--help]\n' "${0##*/}" >&2
      exit 2
      ;;
  esac
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd -- "$script_dir/.."
pwd -P
