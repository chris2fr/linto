#!/usr/bin/env bash

usage() {
    cat <<EOF
Usage: $0 [-h|--help] <fichier à traiter>

Remplace les guillemets français par des guillemets droits.
Crée une copie de sauvegarde avec le suffixe .bak.
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


if [ -f $1 ]; then
   echo $1;
else
   echo "$1 n'existe pas";
   exit 1;
fi

echo $1

sed -i.bak -e 's/« \| »/"/g' $1