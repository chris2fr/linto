#!/usr/bin/env bash
#
# render.sh -- rebuild bibliographies, then render every Quarto document.
#
# Run from the project root (the parent of scripts/), where the .qmd files,
# fr.bib and transcripts live:
#
#     ./scripts/render.sh [-h|--help] [fichier.qmd ...]
#
# Steps:
#   1. build-bib.sh regenerates the pieces-*.bib files from the _pieces-*.yml
#      sources (see scripts/README.md for the full pipeline).
#   2. Every *.qmd in the current directory is rendered with `quarto render`,
#      unless explicit .qmd files are given on the command line.
#
# Options:
#   -h, --help   Show this help and exit.
#
# Exit status: 0 on success, 1 if there is no document to render, 2 on a
# usage error.

# Stop on command failures, unset variables, and failed commands in pipelines.
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [-h|--help] [fichier.qmd ...]

Régénère les bibliographies (build-bib.sh) puis rend chaque document
Quarto avec \`quarto render\`. Sans argument, tous les *.qmd du dossier
courant sont rendus ; les fichiers .qmd passés en argument sont rendus
à la place.

Doit être lancé depuis la racine du projet (le dossier parent de scripts/).

Options:
  -h, --help   Affiche cette aide et quitte.
EOF
}

# --- Parse options -----------------------------------------------------------
# Consume help/options first; stop at the first filename or at `--`.
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
    *) break ;;
  esac
done

# Work from the project root (the parent of scripts/) so the script behaves
# the same whether it is invoked as ./scripts/render.sh or from elsewhere.
cd "$(dirname -- "$0")/.."

# Regenerate the bibliographies first so the render picks up any changes.
./scripts/build-bib.sh

# Render explicit arguments, or every *.qmd in the project root. Since we
# changed directory above, relative filenames supplied by the caller are also
# interpreted relative to that root.
# With nullglob, an unmatched *.qmd expands to no files instead of staying literal.
shopt -s nullglob
qmd_files=("$@")
if [ "$#" -eq 0 ]; then
  qmd_files=(*.qmd)
fi

# Fail clearly if neither the glob nor the caller supplied any documents.
if [ "${#qmd_files[@]}" -eq 0 ]; then
  echo "$0: aucun fichier .qmd à rendre" >&2
  exit 1
fi

for i in "${qmd_files[@]}"; do
  echo "$i"
  quarto render "$i"
done
