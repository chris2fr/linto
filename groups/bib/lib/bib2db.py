#!/usr/bin/env python3
"""fr.bib -> fr.db.   Usage: bib2db.py fr.bib fr.db [--apply] [--prune] [--as-override]

Par défaut : SIMULATION (rien n'est écrit), la liste des changements est affichée champ par champ.
  --apply        écrire les changements (une seule transaction)
  --prune        supprimer les lignes dont la clé est absente du .bib (sinon : seulement signalées)
  --as-override  une valeur modifiée dans le .bib pour un champ non surchargé devient une surcharge "bibtex"
                 (la valeur de base est conservée); par défaut elle remplace la valeur de base.
Règles : un champ déjà surchargé voit sa surcharge mise à jour; un champ supprimé du .bib reçoit une surcharge
null (la valeur de base n'est jamais perdue); un champ inconnu devient une surcharge (il n'existe que dans le .bib).
La colonne markdown n'est jamais lue ni modifiée (une entrée nouvelle reçoit un markdown vide).
Les champs en lecture seule (xpiecefond, xsourcefile, xpages, xmentiontelerecours) sont ignorés.
"""
import base64, copy, json, os, re, sqlite3, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cli import _
from frlib import BIBSET, RO, apply_bib, entry_from_bib, entry_to_row, order_like, put_field, reorder, row_to_entry, set_bibtex

# ------------------------------------------------------------------ BibTeX parser (tolerant, no dependencies)
def _braced(t, i):                       # t[i] == '{' ; returns (content, index after the closing brace)
    depth = 0; j = i
    while j < len(t):
        c = t[j]
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: return t[i+1:j], j+1
        j += 1
    raise ValueError(f'unterminated {{ at offset {i}')

def _quoted(t, i):                       # t[i] == '"'
    depth = 0; j = i + 1
    while j < len(t):
        c = t[j]
        if c == '{': depth += 1
        elif c == '}': depth -= 1
        elif c == '"' and depth == 0: return t[i+1:j], j+1
        j += 1
    raise ValueError(f'unterminated " at offset {i}')

_ws = re.compile(r'\s*'); _tok = re.compile(r'[^\s,#{}()"=]+')

def _value(t, i, strings):
    parts = []
    while True:
        i = _ws.match(t, i).end()
        if t[i] == '{': s, i = _braced(t, i)
        elif t[i] == '"': s, i = _quoted(t, i)
        else:
            m = _tok.match(t, i)
            if not m: raise ValueError(f'bad value at offset {i}')
            s = strings.get(m.group().lower(), m.group()); i = m.end()
        parts.append(s)
        i = _ws.match(t, i).end()
        if i < len(t) and t[i] == '#': i += 1; continue
        return ''.join(parts), i

def parse_bib(t):
    strings, entries, i = {}, [], 0
    head = re.compile(r'@\s*([A-Za-z]+)\s*([{(])')
    while True:
        i = t.find('@', i)
        if i < 0: break
        m = head.match(t, i)
        if not m: i += 1; continue
        typ = m.group(1).lower(); j = m.end()
        if typ in ('comment', 'preamble'):
            i = _braced(t, m.end() - 1)[1] if m.group(2) == '{' else t.find(')', j) + 1
            continue
        if typ == 'string':
            nm = re.compile(r'\s*([^\s=]+)\s*=').match(t, j)
            v, i = _value(t, nm.end(), strings); strings[nm.group(1).lower()] = v
            i = _ws.match(t, i).end() + 1; continue
        close = '}' if m.group(2) == '{' else ')'
        k = t.index(',', j) if ',' in t[j:j+400] else None
        key = t[j:k].strip() if k else None
        j = k + 1; fields = []
        while True:
            j = _ws.match(t, j).end()
            while t[j] == ',': j = _ws.match(t, j + 1).end()
            if t[j] == close: j += 1; break
            nm = re.compile(r'([^\s=,{}()"]+)\s*=').match(t, j)
            if not nm: raise ValueError(f'entry {key}: cannot parse near: {t[j:j+60]!r}')
            v, j = _value(t, nm.end(), strings)
            fields.append((nm.group(1).lower(), v))
        entries.append((typ, key, fields)); i = j
    return entries

# ------------------------------------------------------------------ import
ABSENT = object()

def describe(old, new):
    """Différences champ par champ entre deux entrées (markdown exclu)."""
    out = []
    for name in list(old) + [n for n in new if n not in old]:
        if name in ('markdown', 'key'): continue
        a, b = old.get(name, ABSENT), new.get(name, ABSENT)
        if name == 'bibtex':
            a = old.get(name) ; b = new.get(name)
            a, b = a or {}, b or {}
            for f in list(a) + [f for f in b if f not in a]:
                if a.get(f, ABSENT) != b.get(f, ABSENT): out.append((f'bibtex.{f}', a.get(f, ABSENT), b.get(f, ABSENT)))
        elif a != b:
            out.append((name, a, b))
    return out

def main(bibpath, dbpath, apply=False, prune=False, as_override=False):
    entries = parse_bib(open(bibpath, encoding='utf-8').read())
    db = sqlite3.connect(dbpath); db.row_factory = sqlite3.Row
    rows = {r['id']: r for r in db.execute('SELECT * FROM pieces')}
    seen, changes, new_rows, ro_warn = set(), [], [], []
    for typ, key, fields in entries:
        if key in seen: sys.exit(f'clé en double dans le .bib : {key}')
        seen.add(key)
        meta, bibfields = None, []
        for f, v in fields:
            if f == 'xdbmeta': meta = json.loads(base64.b64decode(v).decode('utf-8'))
            elif f in RO: ro_warn.append((key, f, v))
            else: bibfields.append((f, v))
        r = rows.get(key)
        if r is None:
            new_rows.append((key, entry_from_bib(key, typ, bibfields, meta, markdown=''))); continue
        old = row_to_entry(r); old_order = json.loads(r['field_order'])
        with_md = 'markdown' in old or not old_order
        if meta is not None:
            new = entry_from_bib(key, typ, bibfields, meta, markdown=r['markdown'] if with_md else None)
            ov = dict(new.get('bibtex') or {})
            for f in [f for f in old if f in BIBSET]:
                if f not in new:                                   # champ supprimé du .bib : on garde la valeur de base
                    put_field(new, f, old[f]); ov[f] = None
                elif as_override and new[f] != old[f] and f not in meta.get('base', {}):
                    ov[f] = new[f]; new[f] = old[f]                # modification -> surcharge
            set_bibtex(new, reorder(ov, list(old.get('bibtex') or {})))   # l'ordre des surcharges ne change pas
        else:
            new = copy.deepcopy(old)
            apply_bib(new, typ, bibfields, as_override)
            if with_md and 'markdown' not in new: new['markdown'] = r['markdown']
        if old_order: new = order_like(new, old)
        row = entry_to_row(new)
        upd = {c: v for c, v in row.items() if c not in ('markdown', 'id') and r[c] != v}
        if upd: changes.append((key, old, new, upd))
    missing = [k for k in rows if k not in seen]

    short = lambda v: _('(absent)') if v is ABSENT else _('null (removed from the .bib)') if v is None else (repr(v)[:70] + '…' if len(repr(v)) > 70 else repr(v))
    print(_('.bib: {} entries | db: {} rows').format(len(entries), len(rows)))
    print(_('  unchanged: {}   modified: {}   new: {}   missing from the .bib: {}').format(
        len(entries) - len(changes) - len(new_rows), len(changes), len(new_rows), len(missing)))
    shown = 0
    for key, old, new, upd in changes:
        diffs = describe(old, new)
        if not diffs and set(upd) == {'field_order'}: diffs = [(_('(field order)'), None, None)]
        for name, a, b in diffs:
            if shown < 40: print(f'  ~ {key}  {name}: {short(a)} -> {short(b)}')
            shown += 1
    if shown > 40: print(_('  … {} more differences').format(shown - 40))
    for key, _unused in new_rows[:10]: print(_('  + new entry {} (empty markdown)').format(key))
    for k in missing[:10]: print(_('  - missing from the .bib: {}').format(k) + (_('  (will be deleted)') if prune else _('  (kept)')))
    for key, f, v in ro_warn:
        if str(rows.get(key)[f] if key in rows else None) != v:
            print(_('  ! read-only field {} modified on {}: ignored').format(f, key))
    if not apply:
        print(_('dry run: nothing was written (use --apply)')); return
    with db:
        for key, old, new, upd in changes:
            sets = ', '.join(f'"{c}" = ?' for c in upd)
            db.execute(f'UPDATE pieces SET {sets} WHERE id = ?', list(upd.values()) + [key])
        for key, e in new_rows:
            row = entry_to_row(e)
            db.execute(f'INSERT INTO pieces ({",".join(row)}) VALUES ({",".join("?"*len(row))})', list(row.values()))
        if prune:
            for k in missing: db.execute('DELETE FROM pieces WHERE id = ?', (k,))
    print(_('applied.'))

if __name__ == '__main__':
    a = sys.argv[1:]
    main(a[0], a[1], '--apply' in a, '--prune' in a, '--as-override' in a)
