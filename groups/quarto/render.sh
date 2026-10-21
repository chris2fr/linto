#!/bin/sh
# linto-complete: arg * *.qmd,*.md
#
# render.sh -- rebuild bibliographies, then render Quarto documents.
#
# Run from the project root where the .qmd files, fr.bib and transcripts live:
#
#     linto quarto render [-h|--help] [fichier.qmd ...]
#
# Steps:
#   1. biblio/bibyml2bib.sh regenerates the pieces-*.bib files from the
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
Usage: render.sh [-h|--help] [fichier.qmd ...]

Régénère les bibliographies (bibyml2bib.sh) puis rend chaque document
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
# files are intentionally relative to it. Locate the bibliography builder
# relative to this script so the renderer can be launched from any directory.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Rebuild mappings when present. The biblio helper uses exit 1 for both the
# expected no-mappings case and genuine generation failures, so only suppress
# its specific no-mappings diagnostic.
bib_output=$(
  "$script_dir/../biblio/bibyml2bib.sh" 2>&1
) || bib_status=$?
bib_status=${bib_status:-0}
if [ "$bib_status" -ne 0 ]; then
  case "$bib_output" in
    *'error: no _pieces-*.yml files found; provide BIBTEX_FILE YAML_FILE'*) ;;
    *) printf '%s\n' "$bib_output" >&2; exit "$bib_status" ;;
  esac
fi
[ -z "$bib_output" ] || printf '%s\n' "$bib_output"

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
