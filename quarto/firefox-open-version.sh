#!/usr/bin/env bash

usage() {
    cat <<EOF
Usage: $0 [-h|--help]

Ouvre dans Firefox la dernière version draft-* de _output/versions/.
EOF
}

case "${1-}" in
    -h|--help) usage; exit 0 ;;
    *) if [ "$#" -ne 0 ]; then usage >&2; exit 2; fi ;;
esac

# if [ $# -ne "1" ]; then
#         echo "Usage:  $0 <dossier à ouvrir>"
#         exit 1;
# fi

# if [ -d $1 ]; then
#    echo $1;
# else
#    echo "$1 n'existe pas";
#    exit 1;
# fi
rootdir="$(pwd)/_output/versions/"
workdir="$(ls -1 $rootdir | grep -e '^draft-.*' | sort | tail -n1)"

firefox "$rootdir$workdir"