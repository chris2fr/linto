#!/bin/bash

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