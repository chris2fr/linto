#!/usr/bin/env python3
"""Modèle commun du fr.json « remonté » (importé par les scripts de lib/).

Une entrée du JSON, dans cet ordre :
  key         clé de citation (= nom de la propriété)
  ENTRYTYPE   type d'entrée BibTeX
  <champs>    champs BibTeX (liste BIB) : valeur de base (celle de l'ancien frontmatter, sinon de l'ancien bibtex)
  <autres>    anciens champs frontmatter sans équivalent BibTeX (piece_fond, remarque, avis, ...)
  markdown    transcription
  bibtex      surcharges propres au .bib : {champ: valeur}
                - un champ de BIB présent ici l'emporte, dans le .bib, sur la valeur de base ;
                - null supprime le champ du .bib (la valeur de base est conservée) ;
                - un champ hors BIB n'existe que dans le .bib.
Vue BibTeX d'une entrée = champs BIB de premier niveau, surchargés par « bibtex ».
"""
import json

BIB = ['title','author','abstract','note','number','organization','type','xtype','keywords',
       'xtheme','date','year','language','xcounter','xacronym','shorthand','url',
       'howpublished','xtime','xdatetime','file','publisher','urldate','annote','volume',
       'medium','issue','collection','archive','edition','xduplicate','shorthand2']
BIBSET = frozenset(BIB)
SPECIAL = ('key', 'ENTRYTYPE', 'markdown', 'bibtex')
# colonnes SQL en lecture seule, dérivées des champs « autres »; exportées dans le .bib à titre indicatif
RO = {'xpiecefond': 'piece_fond', 'xsourcefile': 'fichier_source', 'xpages': 'pages',
      'xmentiontelerecours': 'mention_telerecours'}

# ---------------------------------------------------------------- ordre
def reorder(d, order):
    out = {k: d[k] for k in order if k in d}
    out.update({k: v for k, v in d.items() if k not in out})
    return out

def put_field(entry, name, value):
    """Écrit un champ de premier niveau. Un nouveau champ BIB va après le dernier champ BIB, un autre avant markdown."""
    if name in entry:
        entry[name] = value; return
    items = list(entry.items())
    if name in ('markdown', 'bibtex'):
        pos = len(items)
    elif name in BIBSET or name == 'ENTRYTYPE':
        idx = [i for i, (k, _) in enumerate(items) if k in BIBSET or k in ('key', 'ENTRYTYPE')]
        pos = idx[-1] + 1 if idx else 0
    else:
        pos = next((i for i, (k, _) in enumerate(items) if k in ('markdown', 'bibtex')), len(items))
    items.insert(pos, (name, value))
    entry.clear(); entry.update(items)

def set_bibtex(entry, ov):
    entry.pop('bibtex', None)
    if ov: entry['bibtex'] = ov

def order_like(new, old):
    """new, rangé dans l'ordre de old pour les champs existants; les nouveaux champs sont placés au mieux."""
    out = {k: new[k] for k in old if k in new}
    for k, v in new.items():
        if k not in out: put_field(out, k, v)
    return out

# ---------------------------------------------------------------- vue BibTeX
def bibtex_view(entry):
    """-> (type d'entrée, [(champ, valeur), ...]) tel qu'il doit apparaître dans le .bib."""
    ov = entry.get('bibtex') or {}
    et = ov['ENTRYTYPE'] if 'ENTRYTYPE' in ov else entry.get('ENTRYTYPE')
    fields, seen = [], set()
    for name in entry:
        if name in BIBSET:
            seen.add(name)
            v = ov[name] if name in ov else entry[name]
            if v is not None: fields.append((name, v))
    for name, v in ov.items():
        if name in seen or name in ('ENTRYTYPE', 'ID'): continue
        if v is not None: fields.append((name, v))
    return et, fields

def apply_bib(entry, et, fields, as_override=False):
    """Répercute un .bib sur une entrée existante (sans meta). Règles :
    champ déjà surchargé -> la surcharge est mise à jour (supprimée si elle égale la valeur de base);
    champ non surchargé  -> la valeur de base est mise à jour (ou une surcharge si as_override);
    champ disparu du .bib -> surcharge null (la valeur de base est conservée);
    champ inconnu de BIB  -> surcharge (n'existe que dans le .bib)."""
    ov = dict(entry.get('bibtex') or {})
    cur_et, cur_fields = bibtex_view(entry)
    cur, new = dict(cur_fields), dict(fields)
    if et is not None and et != cur_et:
        if 'ENTRYTYPE' in ov: ov['ENTRYTYPE'] = et
        elif 'ENTRYTYPE' in entry and as_override: ov['ENTRYTYPE'] = et
        else: put_field(entry, 'ENTRYTYPE', et)
    for f in list(cur) + [f for f in new if f not in cur]:
        old, nv = cur.get(f), new.get(f)
        if old == nv: continue
        if f in ov:
            if nv is None:
                if f in BIBSET: ov[f] = None
                else: del ov[f]
            elif f in BIBSET and f in entry and entry[f] == nv: del ov[f]
            else: ov[f] = nv
        elif f in BIBSET:
            if nv is None: ov[f] = None
            elif as_override and f in entry: ov[f] = nv
            else: put_field(entry, f, nv)
        else:
            ov[f] = nv
    set_bibtex(entry, ov)
    return entry

def entry_from_bib(key, typ, fields, meta=None, markdown=None):
    """Reconstruit une entrée à partir d'un .bib et de son champ xdbmeta (meta = dict décodé).
    meta : extra (champs « autres »), base (valeur de base des champs surchargés), order, bibtex_order."""
    meta = meta or {}
    base, extra = meta.get('base', {}), meta.get('extra', {})
    top, ov = {'key': key}, {}
    if 'ENTRYTYPE' in base:
        if base['ENTRYTYPE'] is not None: top['ENTRYTYPE'] = base['ENTRYTYPE']
        if typ != base['ENTRYTYPE']: ov['ENTRYTYPE'] = typ
    elif typ is not None:
        top['ENTRYTYPE'] = typ
    shown = set()
    for f, v in fields:
        shown.add(f)
        if f in BIBSET:
            if f in base:
                b = base[f]
                if b is not None: top[f] = b
                if v != b: ov[f] = v
            else:
                top[f] = v
        else:
            ov[f] = v
    for f, b in base.items():                      # champs de base absents du .bib = supprimés
        if f != 'ENTRYTYPE' and f not in shown:
            if b is not None: top[f] = b
            ov[f] = None
    top.update(extra)
    if markdown is not None: top['markdown'] = markdown
    if 'bibtex_order' in meta: ov = reorder(ov, meta['bibtex_order'])
    if ov: top['bibtex'] = ov
    if 'order' in meta: top = reorder(top, meta['order'])
    return top

def check_braces(key, field, v):
    depth = 0
    for ch in v:
        depth += (ch == '{') - (ch == '}')
        if depth < 0: break
    if depth != 0:
        raise ValueError(f'{key}.{field}: accolades déséquilibrées, valeur impossible à écrire en BibTeX')

# ---------------------------------------------------------------- entrée <-> ligne SQL
def entry_to_row(entry):
    key = entry['key']
    row = {'id': key, 'entrytype': entry.get('ENTRYTYPE'), 'markdown': entry.get('markdown', ''),
           'bibtex': None, 'field_order': json.dumps(list(entry))}
    if row['entrytype'] is not None and not isinstance(row['entrytype'], str):
        raise ValueError(f'{key}.ENTRYTYPE: valeur non textuelle')
    if 'bibtex' in entry:
        for f, v in entry['bibtex'].items():
            if v is not None and not isinstance(v, str): raise ValueError(f'{key}.bibtex.{f}: valeur non textuelle')
        row['bibtex'] = json.dumps(entry['bibtex'], ensure_ascii=False)
    for c in BIB: row[c] = None
    extra = {}
    for name, v in entry.items():
        if name in SPECIAL: continue
        if name in BIBSET:
            if not isinstance(v, str): raise ValueError(f'{key}.{name}: valeur non textuelle ({type(v).__name__})')
            row[name] = v
        else:
            extra[name] = v
    row['extra'] = json.dumps(extra, ensure_ascii=False)
    return row

_MISSING = object()

def row_to_entry(r):
    extra = json.loads(r['extra'])
    ov = json.loads(r['bibtex']) if r['bibtex'] is not None else None
    def value(name):
        if name == 'key': return r['id']
        if name == 'markdown': return r['markdown']
        if name == 'bibtex': return ov if ov is not None else _MISSING
        if name == 'ENTRYTYPE': return r['entrytype'] if r['entrytype'] is not None else _MISSING
        if name in BIBSET: return r[name] if r[name] is not None else _MISSING
        return extra.get(name, _MISSING)
    entry = {}
    for name in json.loads(r['field_order']):
        v = value(name)
        if v is not _MISSING: entry[name] = v
    if 'key' not in entry: entry = {'key': r['id'], **entry}
    for c in BIB:                                   # colonnes renseignées après coup
        if r[c] is not None and c not in entry: put_field(entry, c, r[c])
    for name, v in extra.items():
        if name not in entry: put_field(entry, name, v)
    return entry
