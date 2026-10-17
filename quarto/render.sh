#!/bin/sh
#
# render.sh -- rebuild bibliographies, then render every Quarto document.
#
# Run from the project root where the .qmd files, fr.bib and transcripts live:
#
#     linto render [-h|--help] [fichier.qmd ...]
#
# Steps:
#   1. bibtex/build-bib.sh regenerates the pieces-*.bib files from the
#      _pieces-*.yml sources.
#   2. Every *.qmd in the current directory is rendered with `quarto render`,
#      unless explicit .qmd files are given on the command line.
#
# Options:
#   -h, --help   Show this help and exit.
#
# Exit status: 0 on success, 1 if there is no document to render, 2 on a
# usage error.

# Stop on command failures, unset variables, and failed commands in pipelines.
set -eu

usage() {
  cat <<EOF
Usage: $0 [-h|--help] [fichier.qmd ...]

Régénère les bibliographies (build-bib.sh) puis rend chaque document
Quarto avec \`quarto render\`. Sans argument, tous les *.qmd du dossier
courant sont rendus ; les fichiers .qmd passés en argument sont rendus
à la place.

Doit être lancé depuis la racine du projet, où se trouvent les fichiers .qmd.

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

# Keep the caller's working directory as the project root; input and output
# files are intentionally relative to it. Locate build-bib.sh relative to this
# script so the renderer can be launched from any working directory.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$script_dir/../bibtex/build-bib.sh"

# Render explicit arguments, or every *.qmd in the caller's project root.
if [ "$#" -eq 0 ]; then
  set -- *.qmd
  [ -f "$1" ] || {
    echo "$0: aucun fichier .qmd à rendre" >&2
    exit 1
  }
fi

for i do
  echo "$i"
  quarto render "$i"
done
