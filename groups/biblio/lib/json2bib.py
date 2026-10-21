#!/usr/bin/env python3
"""fr.json (remonté) -> BibTeX sur stdout.   Usage: json2bib.py entrée.json

La clé de chaque entrée est le nom de sa propriété. Les champs sont la vue BibTeX de l'entrée : champs BibTeX de
premier niveau, remplacés par les surcharges du champ "bibtex" (null = champ omis). Les « % » sont écrits « \\% »."""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frlib import bibtex_view

sys.stdout.reconfigure(encoding='utf-8', newline='\n')
esc = lambda v: re.sub(r'(?<!\\)%', r'\\%', v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))
d = json.load(open(sys.argv[1], encoding='utf-8'))
for key, e in d.items():
    et, fields = bibtex_view(e)
    if not et:
        print(f'Ignorée (pas de ENTRYTYPE) : {key}', file=sys.stderr); continue
    body = ',\n'.join(f'  {f} = {{{esc(v)}}}' for f, v in fields)
    sys.stdout.write(f'@{et}{{{key},\n{body}\n}}\n\n')
