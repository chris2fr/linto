#!/usr/bin/env python3
"""fr.db -> fr.bib.   Usage: db2bib.py fr.db fr.bib

Chaque entrée devient un @type{clé, ...} dont les champs sont la vue BibTeX de l'entrée (valeurs de base,
remplacées par les surcharges "bibtex"; les surcharges null sont omises). Sont ajoutés :
  * xpiecefond, xsourcefile, xpages, xmentiontelerecours : informatifs, EN LECTURE SEULE (dérivés de "extra") ;
  * xdbmeta : base64(JSON) de ce que BibTeX ne peut pas montrer : "extra" (champs sans équivalent BibTeX),
    "base" (valeur de base des champs surchargés). Opaque à dessein.
L'ordre des champs n'est pas stocké : alphabétique, ou celui de configdata.bib.field-order (config.yml).
Le script vérifie, pour chaque entrée, que le .bib permet de reconstruire exactement l'entrée (hors markdown).
La colonne markdown n'est jamais exportée."""
import base64, json, os, sqlite3, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cli import _
from frlib import BIBSET, RO, bibtex_view, check_braces, entry_from_bib, row_to_entry

def main(src, dst):
    db = sqlite3.connect(src); db.row_factory = sqlite3.Row
    n = 0
    stdout = dst == '-'
    with (open(sys.stdout.fileno(), 'w', encoding='utf-8', newline='\n', closefd=False) if stdout
          else open(dst, 'w', encoding='utf-8', newline='\n')) as out:
        out.write('@comment{x-kbibtex-encoding=utf-8}\n\n')
        for r in db.execute('SELECT * FROM pieces ORDER BY n'):
            e = row_to_entry(r); key = e['key']
            et, fields = bibtex_view(e)
            if et is None: raise ValueError(_('{}: no ENTRYTYPE').format(key))
            for f, v in fields: check_braces(key, f, v)
            ov = e.get('bibtex') or {}
            meta = {}
            extra = {k: v for k, v in e.items() if k not in ('key', 'ENTRYTYPE', 'markdown', 'bibtex') and k not in BIBSET}
            if extra: meta['extra'] = extra
            base = {f: e.get(f) for f in ov if f in BIBSET or f == 'ENTRYTYPE'}
            if base: meta['base'] = base
            rec = entry_from_bib(key, et, fields, meta, markdown=e.get('markdown'))
            if json.dumps(rec, ensure_ascii=False) != json.dumps(e, ensure_ascii=False):
                raise ValueError(_('{}: the .bib cannot rebuild the entry').format(key))
            lines = list(fields)
            for f in RO:
                if r[f] is not None: lines.append((f, str(r[f])))
            if meta:
                blob = json.dumps(meta, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
                lines.append(('xdbmeta', base64.b64encode(blob).decode('ascii')))
            out.write(f'@{et}{{{key},\n')
            out.write(',\n'.join(f'  {f} = {{{v}}}' for f, v in lines))
            out.write('\n}\n\n')
            n += 1
    print(_('{} entries -> {}').format(n, 'stdout' if stdout else dst), file=sys.stderr)

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
