#!/bin/bash

if [ $# -ne "1" ]; then
        echo "Usage:  $0 <fichier à traiter>"
        exit 1;
fi


if [ -f $1 ]; then
   echo $1;
else
   echo "$1 n'existe pas";
   exit 1;
fi

echo $1

sed -i.bak -e 's/« \| »/"/g' $1