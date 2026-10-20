#!/usr/bin/env python3
"""fr.bib -> fr.db.   Usage: fr_bib2db.py fr.bib fr.db [--apply] [--add-columns] [--prune]

Default is a DRY RUN: it prints what would change and touches nothing.
  --apply        write the changes (one transaction)
  --add-columns  turn BibTeX fields that have no column yet into new TEXT columns (otherwise they abort the import)
  --prune        delete rows whose key is not in the .bib (otherwise they are only reported)
The markdown column is never read or written, except that a brand-new entry gets an empty markdown.
Read-only fields (xpiecefond, xsourcefile, xpages, xmentiontelerecours) are ignored; edit the frontmatter JSON instead.
"""
import base64, json, re, sqlite3, sys

STRUCT = {'n','id','entrytype','frontmatter','markdown','entry_order','bibtex_order'}
RO = {'xpiecefond','xsourcefile','xpages','xmentiontelerecours'}
DEFAULT_ORDER = 'key,frontmatter,markdown,bibtex'

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
def reconcile(base, bibfields, ei):
    keep = [f for f in base if f in ('ID', 'ENTRYTYPE') or f in bibfields]
    return keep + [f for f in bibfields if f not in keep]

def main(bibpath, dbpath, apply=False, add_columns=False, prune=False):
    entries = parse_bib(open(bibpath, encoding='utf-8').read())
    db = sqlite3.connect(dbpath); db.row_factory = sqlite3.Row
    info = db.execute('PRAGMA table_xinfo(pieces)').fetchall()
    cols = [r['name'] for r in info if r['hidden'] == 0 and r['name'] not in STRUCT]
    rows = {r['id']: r for r in db.execute('SELECT * FROM pieces')}
    seen, unknown, changes, new, ro_warn = set(), {}, [], [], []
    for typ, key, fields in entries:
        if key in seen: sys.exit(f'duplicate key in .bib: {key}')
        seen.add(key)
        bib, meta, names = {}, {}, []
        for f, v in fields:
            if f == 'xdbmeta':
                meta = json.loads(base64.b64decode(v).decode('utf-8'))
            elif f in RO: bib.setdefault('_ro', {})[f] = v
            elif f in STRUCT: sys.exit(f'ABORT: {key}: field "{f}" clashes with an internal column name')
            elif f in cols or f in unknown.get(key, ()): bib[f] = v; names.append(f)
            else: unknown.setdefault(key, []).append(f); bib[f] = v; names.append(f)
        r = rows.get(key)
        has_meta = any(f == 'xdbmeta' for f, _ in fields)
        if r is None:
            new.append((key, typ, bib, names, meta)); continue
        ch = {}
        if typ != r['entrytype']: ch['entrytype'] = (r['entrytype'], typ)
        for c in cols:
            if r[c] != bib.get(c): ch[c] = (r[c], bib.get(c))
        for f in unknown.get(key, ()):
            if bib.get(f) is not None: ch[f] = (None, bib[f])
        for f, v in bib.get('_ro', {}).items():
            if str(r[f]) != v: ro_warn.append((key, f, r[f], v))
        # layout: keep the db's order for existing fields, append new ones; ENTRYTYPE/ID keep their place
        if json.loads(r['bibtex_order']):
            order = reconcile(json.loads(r['bibtex_order']), names, None)
        else:                                          # wiped db: rebuild from the .bib (+ meta['ei'])
            order = list(names); ei = meta.get('ei', len(order)); order[ei:ei] = ['ENTRYTYPE', 'ID']
        if order != json.loads(r['bibtex_order']): ch['bibtex_order'] = (r['bibtex_order'], json.dumps(order))
        if has_meta:
            fm = json.dumps(meta.get('frontmatter', {}), ensure_ascii=False)
            if fm != r['frontmatter']: ch['frontmatter'] = (r['frontmatter'], fm)
            eo = meta.get('entry_order', DEFAULT_ORDER)
            if eo != r['entry_order']: ch['entry_order'] = (r['entry_order'], eo)
        if ch: changes.append((key, ch))
    missing = [k for k in rows if k not in seen]

    short = lambda v: (repr(v)[:70] + '…') if v is not None and len(repr(v)) > 70 else repr(v)
    print(f'.bib: {len(entries)} entries | db: {len(rows)} rows')
    print(f'  unchanged: {len(entries) - len(changes) - len(new)}   changed: {len(changes)}   new: {len(new)}   '
          f'missing from .bib: {len(missing)}')
    for key, ch in changes[:25]:
        for c, (a, b) in ch.items(): print(f'  ~ {key}  {c}: {short(a)} -> {short(b)}')
    if len(changes) > 25: print(f'  … {len(changes) - 25} more changed entries')
    for key, *_ in new[:10]: print(f'  + new entry {key} (markdown will be empty)')
    for k in missing[:10]: print(f'  - not in .bib: {k}' + ('  (will be deleted)' if prune else '  (kept)'))
    for key, f, a, b in ro_warn[:10]: print(f'  ! read-only field {f} edited on {key} ({a!r} -> {b!r}): ignored, edit frontmatter instead')
    newcols = sorted({f for fl in unknown.values() for f in fl})
    if newcols and not add_columns:
        sys.exit(f'ABORT: fields without a column: {newcols}. Re-run with --add-columns to create them.')
    if not apply:
        print('dry run: nothing written (use --apply)'); return
    with db:
        for c in newcols:
            db.execute(f'ALTER TABLE pieces ADD COLUMN "{c}" TEXT'); cols.append(c)
        for key, ch in changes:
            sets = ', '.join(f'"{c}" = ?' for c in ch)
            db.execute(f'UPDATE pieces SET {sets} WHERE id = ?', [b for _, b in ch.values()] + [key])
        for key, typ, bib, names, meta in new:
            order = list(names); ei = meta.get('ei', len(order)); order[ei:ei] = ['ENTRYTYPE', 'ID']
            vals = {'id': key, 'entrytype': typ, 'markdown': '',
                    'frontmatter': json.dumps(meta.get('frontmatter', {}), ensure_ascii=False),
                    'entry_order': meta.get('entry_order', DEFAULT_ORDER), 'bibtex_order': json.dumps(order)}
            vals.update({c: bib.get(c) for c in cols})
            db.execute(f'INSERT INTO pieces ({",".join(chr(34)+c+chr(34) for c in vals)}) VALUES ({",".join("?"*len(vals))})', list(vals.values()))
        if prune:
            for k in missing: db.execute('DELETE FROM pieces WHERE id = ?', (k,))
    print('applied.')

if __name__ == '__main__':
    a = sys.argv[1:]
    main(a[0], a[1], '--apply' in a, '--add-columns' in a, '--prune' in a)
