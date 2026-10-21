#!/usr/bin/env python3
"""BibTeX -> fr.json (remonté).   Usage: bib2json.py fichier.bib entrée.json|'' sortie.json|'' [1]

Répercute les entrées du .bib sur les clés JSON existantes (voir frlib.apply_bib : surcharge mise à jour, valeur de
base mise à jour, champ disparu = surcharge null) et crée les clés absentes du JSON. 4e argument "1" : --as-override.
Les champs xdbmeta et en lecture seule (xpiecefond...) sont ignorés. Sortie : fichier, ou stdout si vide."""
import json, os, sys
import bibtexparser
from bibtexparser.bparser import BibTexParser
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frlib import RO, apply_bib, entry_from_bib

bib_path, json_in, json_out = sys.argv[1:4]
as_override = len(sys.argv) > 4 and sys.argv[4] == '1'

parser = BibTexParser(
    common_strings=True,
    ignore_nonstandard_types=False,   # accepte @misc, @article, ...
    homogenize_fields=False,          # conserve xtype, xtheme, xcounter...
)
parser.customization = None
with open(bib_path, encoding='utf-8') as f:
    bib = bibtexparser.load(f, parser=parser)

if not json_in:
    data = {}
else:
    with open(json_in, encoding='utf-8') as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise SystemExit(f"Le JSON doit contenir un objet indexé par clé : {json_in}")

unesc = lambda v: v.replace('\\%', '%') if isinstance(v, str) else v
created = []
for entry in bib.entries:
    key, typ = entry['ID'], entry['ENTRYTYPE']
    fields = [(k, unesc(v)) for k, v in entry.items()
              if k not in ('ID', 'ENTRYTYPE', 'xdbmeta') and k not in RO]
    if key in data:
        apply_bib(data[key], typ, fields, as_override)
    else:
        data[key] = entry_from_bib(key, typ, fields, None, markdown='')
        created.append(key)

# chaque enregistrement commence par "key", son propre nom de propriété
for key, entry in data.items():
    if isinstance(entry, dict):
        data[key] = {'key': key, **{n: v for n, v in entry.items() if n != 'key'}}

to_stdout = not json_out
if to_stdout:
    json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write('\n')
else:
    with open(json_out, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

if created:
    report = sys.stderr if to_stdout else sys.stdout
    print(f"Nouvelles clés créées depuis {bib_path} :", file=report)
    for key in created:
        print("  -", key, file=report)
