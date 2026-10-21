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
import sys
from pathlib import Path

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
# L'ordre des champs n'est plus stocké : il est alphabétique, ou celui de configdata.bib.field-order
# (config.yml) pour les champs listés, les autres suivant par ordre alphabétique.
_HEAD = ('key', 'ENTRYTYPE')            # toujours en tête d'une entrée
_TAIL = ('markdown', 'bibtex')          # toujours en fin d'entrée
_field_order = None

def field_order():
    """Liste configurée configdata.bib.field-order (vide si absente ou illisible)."""
    global _field_order
    if _field_order is None:
        _field_order = []
        root = Path(__file__).resolve().parents[3]
        try:
            sys.path.insert(0, str(root / 'lib'))
            import config
            data = config.load(root / 'config.yml', defaults_root=root, data_root=config.data_directory(),
                               overlays=config.config_overlays())
            order = config.configdata(data, 'bib').get('bib', {}).get('field-order', [])
            if isinstance(order, list) and all(isinstance(n, str) for n in order):
                _field_order = list(dict.fromkeys(order))
        except Exception:
            pass
    return _field_order

def _rank(name):
    order = field_order()
    if name in _HEAD: return (0, _HEAD.index(name), '')
    if name in _TAIL: return (3, _TAIL.index(name), '')
    if name in order: return (1, order.index(name), '')
    return (2, 0, name)

def reorder(d, order=None):
    """d rangé dans l'ordre des champs (configuré, sinon alphabétique)."""
    return {k: d[k] for k in sorted(d, key=_rank)}

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
    fields.sort(key=lambda f: _rank(f[0]))
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
    meta : extra (champs « autres »), base (valeur de base des champs surchargés)."""
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
    if ov: top['bibtex'] = reorder(ov)
    return reorder(top)

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
           'bibtex': None}
    if row['entrytype'] is not None and not isinstance(row['entrytype'], str):
        raise ValueError(f'{key}.ENTRYTYPE: valeur non textuelle')
    if 'bibtex' in entry:
        for f, v in entry['bibtex'].items():
            if v is not None and not isinstance(v, str): raise ValueError(f'{key}.bibtex.{f}: valeur non textuelle')
        row['bibtex'] = json.dumps(reorder(entry['bibtex']), ensure_ascii=False)
    for c in BIB: row[c] = None
    extra = {}
    for name, v in entry.items():
        if name in SPECIAL: continue
        if name in BIBSET:
            if not isinstance(v, str): raise ValueError(f'{key}.{name}: valeur non textuelle ({type(v).__name__})')
            row[name] = v
        else:
            extra[name] = v
    row['extra'] = json.dumps(reorder(extra), ensure_ascii=False)
    return row

def row_to_entry(r):
    extra = json.loads(r['extra'])
    ov = json.loads(r['bibtex']) if r['bibtex'] is not None else None
    entry = {'key': r['id']}
    if r['entrytype'] is not None: entry['ENTRYTYPE'] = r['entrytype']
    for c in BIB:
        if r[c] is not None: entry[c] = r[c]
    entry.update(extra)
    entry['markdown'] = r['markdown']
    if ov is not None: entry['bibtex'] = ov
    return reorder(entry)
