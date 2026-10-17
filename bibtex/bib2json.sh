#!/bin/sh
set -eu

usage() {
  cat <<EOF
Usage: $0 [-h|--help] <fichier.bib> <entrée.json> <sortie.json>

Injecte les entrées BibTeX dans le champ bibtex du fichier JSON.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  --) shift ;;
  -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
esac
if [ "$#" -ne 3 ]; then
  usage >&2
  exit 2
fi

bib=$1
json_in=$2
json_out=$3

# une seule fois
# python3 -m pip install bibtexparser

# pip install bibtexparser

python3 - "$bib" "$json_in" "$json_out" <<'PY'
import json, sys, bibtexparser
from bibtexparser.bparser import BibTexParser

bib_path, json_in, json_out = sys.argv[1:4]

parser = BibTexParser(
    common_strings=True,
    ignore_nonstandard_types=False,   # accepte @misc, @article, ...
    homogenize_fields=False,          # conserve xtype, xtheme, xcounter...
)
parser.customization = None

with open(bib_path) as f:
    bib = bibtexparser.load(f, parser=parser)

by_id = {e['ID']: e for e in bib.entries}

with open(json_in) as f:
    data = json.load(f)

missing = []
for key, entry in data.items():
    if key in by_id:
        # remplace le champ bibtex (en retirant l'échappement LaTeX \%)
        entry['bibtex'] = {k: v.replace('\\%', '%') for k, v in by_id[key].items()}
    else:
        missing.append(key)

with open(json_out, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

if missing:
    print(f"Entrées de {json_in} absentes de {bib_path} :")
    for k in missing:
        print("  -", k)
PY
