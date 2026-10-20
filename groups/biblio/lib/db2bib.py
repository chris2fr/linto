#!/usr/bin/env python3
"""fr.db -> fr.bib.   Usage: fr_db2bib.py fr.db fr.bib

Every non-markdown column goes into the .bib:
  * bibtex columns  -> ordinary BibTeX fields, in the entry's original field order (NULL = field omitted)
  * xpiecefond, xsourcefile, xpages, xmentiontelerecours -> informational, READ-ONLY (derived from frontmatter)
  * xdbmeta         -> base64(JSON) with what BibTeX cannot show: frontmatter, plus layout that differs from the default.
                       Opaque on purpose: base64 contains nothing a BibTeX/LaTeX parser could interpret.
The markdown column is never exported.
"""
import base64, json, sqlite3, sys

STRUCT = {'n','id','entrytype','frontmatter','markdown','entry_order','bibtex_order'}
RO = ['xpiecefond','xsourcefile','xpages','xmentiontelerecours']
DEFAULT_ORDER = 'key,frontmatter,markdown,bibtex'

def check_braces(key, field, v):
    depth = 0
    for ch in v:
        depth += (ch == '{') - (ch == '}')
        if depth < 0: break
    if depth != 0:
        raise ValueError(f'{key}.{field}: unbalanced braces, cannot be written as a BibTeX value')

def main(src, dst):
    db = sqlite3.connect(src); db.row_factory = sqlite3.Row
    info = db.execute('PRAGMA table_xinfo(pieces)').fetchall()
    fields = [r['name'] for r in info if r['hidden'] == 0 and r['name'] not in STRUCT]   # real, editable columns
    n = 0
    with open(dst, 'w', encoding='utf-8', newline='\n') as out:
        out.write('@comment{x-kbibtex-encoding=utf-8}\n\n')
        for r in db.execute('SELECT * FROM pieces ORDER BY n'):
            order = json.loads(r['bibtex_order'])
            names = [f for f in order if f not in ('ID', 'ENTRYTYPE') and f in fields]
            names += [f for f in fields if f not in names and r[f] is not None]      # columns added after the import
            lines = []
            for f in names:
                v = r[f]
                if v is None: continue
                check_braces(r['id'], f, v)
                lines.append((f, v))
            for f in RO:
                if r[f] is not None: lines.append((f, str(r[f])))
            meta = {}
            fm = json.loads(r['frontmatter'])
            if fm: meta['frontmatter'] = fm
            if r['entry_order'] != DEFAULT_ORDER: meta['entry_order'] = r['entry_order']
            ei = order.index('ENTRYTYPE')
            if ei != len(order) - 2: meta['ei'] = ei
            if meta:
                blob = json.dumps(meta, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
                lines.append(('xdbmeta', base64.b64encode(blob).decode('ascii')))
            out.write(f'@{r["entrytype"]}{{{r["id"]},\n')
            out.write(',\n'.join(f'  {f} = {{{v}}}' for f, v in lines))
            out.write('\n}\n\n')
            n += 1
    print(f'{n} entries -> {dst}')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
