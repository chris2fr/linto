#!/usr/bin/env python3
"""fr.json (bibtex + frontmatter) -> fr.json « remonté ».   Usage: lift.py entrée.json sortie.json

Chaque champ de "bibtex" ou de "frontmatter" monte d'un cran, au niveau de l'entrée :
  - égal dans les deux, ou présent dans un seul          -> monte tel quel ;
  - présent dans les deux avec des valeurs différentes   -> monte la valeur du frontmatter,
                                                           la valeur bibtex reste dans "bibtex" (surcharge).
"frontmatter" est donc vidé (supprimé); "bibtex" ne garde que les surcharges (supprimé s'il est vide).
ID (toujours égal à key) n'est pas conservé. Ordre : key, ENTRYTYPE, champs BibTeX, autres champs, markdown, bibtex.
"""
import collections, json, sys
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from frlib import BIB, BIBSET, bibtex_view

def same(a, b):
    return a == b and type(a) is type(b)

def lift(d):
    out, st = {}, collections.Counter()
    for key, e in d.items():
        unexpected = set(e) - {'key', 'frontmatter', 'markdown', 'bibtex'}
        if unexpected: sys.exit(f'{key}: clés inattendues {sorted(unexpected)} (fichier déjà remonté ?)')
        b, f = e.get('bibtex', {}), e.get('frontmatter', {})
        assert e['key'] == key and b.get('ID', key) == key and f.get('ID', key) == key, key
        assert not (set(b) - set(BIB) - {'ID', 'ENTRYTYPE'}), (key, set(b) - set(BIB))
        assert not ((set(b) | set(f)) & {'key', 'markdown', 'bibtex', 'frontmatter'}), key
        top, ov = {}, {}
        for n, bv in b.items():
            if n == 'ID': continue
            if n in f:
                top[n] = f[n]
                if same(bv, f[n]): st['égaux (remontés)'] += 1
                else: ov[n] = bv; st['divergents (frontmatter remonté, bibtex en surcharge)'] += 1
            else:
                top[n] = bv; st['bibtex seul (remontés)'] += 1
        for n, fv in f.items():
            if n == 'ID' or n in b: continue
            top[n] = fv; st['frontmatter seul (remontés)'] += 1
        new = {'key': key}
        if 'ENTRYTYPE' in top: new['ENTRYTYPE'] = top['ENTRYTYPE']
        new.update({n: v for n, v in top.items() if n in BIBSET})
        new.update({n: v for n, v in top.items() if n not in BIBSET and n != 'ENTRYTYPE'})
        new['markdown'] = e['markdown']
        if ov: new['bibtex'] = ov; st['entrées avec surcharges'] += 1
        out[key] = new
    return out, st

def verify(old, new):
    """Rien ne se perd : tout champ frontmatter est au premier niveau, tout champ bibtex est dans la vue BibTeX."""
    added = 0
    for key, e in old.items():
        n = new[key]
        for name, v in e.get('frontmatter', {}).items():
            if name != 'ID': assert same(n[name], v), (key, name)
        et, fields = bibtex_view(n); view = dict(fields)
        for name, v in e.get('bibtex', {}).items():
            if name == 'ID': continue
            if name == 'ENTRYTYPE': assert et == v, (key, name)
            else: assert view[name] == v, (key, name)
        added += len(set(view) - set(e.get('bibtex', {})))
        assert n['markdown'] == e['markdown']
    return added

if __name__ == '__main__':
    d = json.load(open(sys.argv[1], encoding='utf-8'))
    new, st = lift(d)
    added = verify(d, new)
    text = json.dumps(new, indent=2, ensure_ascii=False)
    if sys.argv[2] == '-':
        sys.stdout.write(text)
    else:
        with open(sys.argv[2], 'w', encoding='utf-8') as fh:
            fh.write(text)
    print(f'{len(new)} entrées -> {"stdout" if sys.argv[2] == "-" else sys.argv[2]}', file=sys.stderr)
    for k, v in st.items(): print(f'  {v:6}  {k}', file=sys.stderr)
    print(f'  {added:6}  champs désormais présents dans le .bib alors qu\'ils n\'étaient que dans le frontmatter', file=sys.stderr)
