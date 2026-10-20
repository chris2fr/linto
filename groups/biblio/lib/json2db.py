#!/usr/bin/env python3
"""fr.json -> fr.db (SQLite), lossless.  Usage: fr_json2db.py fr.json fr.db"""
import json, sqlite3, sys, os

src, dst = sys.argv[1], sys.argv[2]
BIB = ['title','author','abstract','note','number','organization','type','xtype','keywords',
       'xtheme','date','year','language','xcounter','xacronym','shorthand','url',
       'howpublished','xtime','xdatetime','file','publisher','urldate','annote','volume',
       'medium','issue','collection','archive','edition','xduplicate','shorthand2']

d = json.load(open(src, encoding='utf-8'))
if os.path.exists(dst): os.remove(dst)
db = sqlite3.connect(dst)
db.execute(f"""
CREATE TABLE pieces (
  n INTEGER PRIMARY KEY,                     -- stable row number (keeps the FTS index valid across VACUUM)
  id TEXT NOT NULL UNIQUE,                   -- = cite key
  entrytype TEXT,
  {", ".join(f"{c} TEXT" for c in BIB)},
  frontmatter TEXT NOT NULL CHECK (json_valid(frontmatter)),  -- raw JSON, source of truth for frontmatter
  markdown TEXT NOT NULL,
  -- read-only columns derived from frontmatter
  xpiecefond INTEGER GENERATED ALWAYS AS (json_extract(frontmatter,'$.piece_fond')) VIRTUAL,
  xsourcefile TEXT   GENERATED ALWAYS AS (json_extract(frontmatter,'$.fichier_source')) VIRTUAL,
  xpages INTEGER     GENERATED ALWAYS AS (json_extract(frontmatter,'$.pages')) VIRTUAL,
  xmentiontelerecours TEXT GENERATED ALWAYS AS (json_extract(frontmatter,'$.mention_telerecours')) VIRTUAL,
  -- layout, only needed for byte-identical export
  entry_order TEXT NOT NULL,                 -- order of top-level keys, e.g. key,frontmatter,markdown,bibtex
  bibtex_order TEXT NOT NULL CHECK (json_valid(bibtex_order))  -- JSON array of bibtex field names in original order
)""")
for k, v in d.items():
    b, f = v['bibtex'], v['frontmatter']
    assert b['ID'] == k == v['key']
    unknown = set(b) - set(BIB) - {'ID', 'ENTRYTYPE'}
    assert not unknown, (k, unknown)
    row = {'id': k, 'entrytype': b['ENTRYTYPE'],
           'frontmatter': json.dumps(f, ensure_ascii=False),
           'markdown': v['markdown'],
           'entry_order': ','.join(v.keys()),
           'bibtex_order': json.dumps(list(b.keys()))}
    for c in BIB: row[c] = b.get(c)          # absent field -> NULL
    db.execute(f'INSERT INTO pieces ({",".join(row)}) VALUES ({",".join("?"*len(row))})', list(row.values()))

# ---- full-text search: external-content FTS5 (no duplicated text), accent- and case-insensitive ----
FTS = ['id','title','author','abstract','note','keywords','organization','markdown']
cl = ', '.join(FTS)
db.execute(f"""CREATE VIRTUAL TABLE pieces_fts USING fts5(
  {cl}, content='pieces', content_rowid='n',
  tokenize='unicode61 remove_diacritics 2')""")
new = ', '.join(f'new.{c}' for c in FTS); old = ', '.join(f'old.{c}' for c in FTS)
db.executescript(f"""
CREATE TRIGGER pieces_ai AFTER INSERT ON pieces BEGIN
  INSERT INTO pieces_fts(rowid, {cl}) VALUES (new.n, {new});
END;
CREATE TRIGGER pieces_ad AFTER DELETE ON pieces BEGIN
  INSERT INTO pieces_fts(pieces_fts, rowid, {cl}) VALUES ('delete', old.n, {old});
END;
CREATE TRIGGER pieces_au AFTER UPDATE OF {cl} ON pieces BEGIN
  INSERT INTO pieces_fts(pieces_fts, rowid, {cl}) VALUES ('delete', old.n, {old});
  INSERT INTO pieces_fts(rowid, {cl}) VALUES (new.n, {new});
END;
""")
db.execute("INSERT INTO pieces_fts(pieces_fts) VALUES ('rebuild')")
db.commit(); db.close()
print(f'{len(d)} rows -> {dst}')
