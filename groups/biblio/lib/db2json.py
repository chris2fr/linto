#!/usr/bin/env python3
"""fr.db -> fr.json.  Usage: fr_db2json.py fr.db fr.json
Columns are authoritative for bibtex fields; frontmatter JSON for frontmatter."""
import json, sqlite3, sys

src, dst = sys.argv[1], sys.argv[2]
db = sqlite3.connect(src); db.row_factory = sqlite3.Row
out = {}
for r in db.execute('SELECT * FROM pieces ORDER BY n'):
    bib = {}
    for name in json.loads(r['bibtex_order']):
        if name == 'ID': bib[name] = r['id']
        elif name == 'ENTRYTYPE': bib[name] = r['entrytype']
        else: bib[name] = r[name]
    # fields added later in the database (not in bibtex_order) go at the end; NULL = absent
    known = set(bib)
    for name in r.keys():
        if name in ('n','id','entrytype','frontmatter','markdown','entry_order','bibtex_order') \
           or name.startswith('xpiece') or name in ('xsourcefile','xpages','xmentiontelerecours'): continue
        if name not in known and r[name] is not None: bib[name] = r[name]
    bib = {k: v for k, v in bib.items() if v is not None}
    parts = {'key': r['id'], 'frontmatter': json.loads(r['frontmatter']),
             'markdown': r['markdown'], 'bibtex': bib}
    out[r['id']] = {k: parts[k] for k in r['entry_order'].split(',')}
with open(dst, 'w', encoding='utf-8') as f:
    f.write(json.dumps(out, indent=2, ensure_ascii=False))   # same formatting as the original, no trailing newline
print(f'{len(out)} entries -> {dst}')
