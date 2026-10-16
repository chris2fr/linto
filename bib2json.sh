#!/usr/bin/env bash
# Usage : bib2json.sh <fichier.bib> <entrée.json> <sortie.json>
set -euo pipefail

bib="${1:?Usage: $0 <fichier.bib> <entrée.json> <sortie.json>}"
json_in="${2:?Usage: $0 <fichier.bib> <entrée.json> <sortie.json>}"
json_out="${3:?Usage: $0 <fichier.bib> <entrée.json> <sortie.json>}"

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
