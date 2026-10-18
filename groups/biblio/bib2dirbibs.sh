#!/bin/sh
# linto-complete: arg 1 *.bib
#
# bib2dirbibs.sh -- split a BibTeX file into one file per entry.
#
# Calls lib/mkbib.awk, which reads the given .bib file and writes each entry
# to ./bib/<clé>.bib (the directory is created if missing).
#
# Usage:
#   ./bib2dirbibs.sh [-h|--help] <fichier.bib>
#
# Options:
#   -h, --help   Show this help and exit.
#
# The single remaining argument must be an existing .bib file.
# Exit status: 0 on success, 1 on a missing/invalid file, 2 on a usage error.

set -eu

usage() {
  cat <<EOF
Usage: $0 [-h|--help] <fichier à traiter>

Éclate un fichier BibTeX en un fichier par entrée dans ./bib/<clé>.bib.

Options:
  -h, --help   Affiche cette aide et quitte.
EOF
}

# --- Parse options -----------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
    *) break ;;
  esac
done

# --- Validate the input file ------------------------------------------------
if [ $# -ne 1 ]; then
  usage >&2
  exit 2
fi

if [ -f "$1" ]; then
  echo "$1"
else
  echo "$1 n'existe pas" >&2
  exit 1
fi

# --- Split the bibliography -------------------------------------------------
# lib/mkbib.awk reads the input (given via -f) and writes ./bib/<clé>.bib.
# Resolve it relative to this script so bib2dirbibs.sh works from any directory.
mkdir -p ./bib

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
awk -f "$script_dir/lib/mkbib.awk" "$1"
