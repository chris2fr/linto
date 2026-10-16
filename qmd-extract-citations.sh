#!/bin/sh
# Usage: ./qmd-extract-citations.sh <fichier>
# Liste les valeurs uniques de [@...], dans l'ordre de première apparition.

if [ $# -ne 1 ]; then
    echo "Usage: $0 <fichier>" >&2
    exit 1
fi

if [ ! -r "$1" ]; then
    echo "Erreur : '$1' introuvable ou illisible" >&2
    exit 1
fi

grep -o '\[@[^]]*\]' "$1" \
    | sed 's/^\[@//; s/\]$//' \
    | awk '!seen[$0]++'
