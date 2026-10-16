#!/bin/sh
# Liste les valeurs uniques de [@...], dans l'ordre de première apparition.

usage() {
    cat <<EOF
Usage: $0 [-h|--help] <fichier.qmd>

Liste les valeurs uniques de [@...], dans l'ordre de première apparition.
EOF
}

case "${1-}" in
    -h|--help) usage; exit 0 ;;
    --) shift ;;
    -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$#" -ne 1 ]; then
    usage >&2
    exit 2
fi

if [ ! -r "$1" ]; then
    echo "Erreur : '$1' introuvable ou illisible" >&2
    exit 1
fi

grep -o '\[@[^]]*\]' "$1" \
    | sed 's/^\[@//; s/\]$//' \
    | awk '!seen[$0]++'
