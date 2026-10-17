function format_begin(fld, count) {
    printf "#!/bin/bash\n\nif [ $# -ne \"1\" ]; then\n        echo \"Usage:  $0 <fichier à traiter>\"\n        exit 1;\nfi\n\n"
    printf "\nif [ -f $1 ]; then\n   echo $1;\nelse\n   echo \"$1 n'existe pas\";\n    exit 1;\n fi;\n\n"
}

function format_output(vals, fldidx, fld) {
    publisher = vals[fldidx["publisher"]]
    howpublished = vals[fldidx["howpublished"]]

    if (howpublished && !publisher)
        printf "sed -i -e 's/howpublished = {%s},/publisher = {%s},/g' $1/%s.bib\n", howpublished, howpublished, key
}
