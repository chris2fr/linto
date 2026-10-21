#!/usr/bin/env python3
"""fr.db -> fr.json (remonté).  Usage: db2json.py fr.db fr.json"""
import json, os, sqlite3, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frlib import row_to_entry

src, dst = sys.argv[1], sys.argv[2]
db = sqlite3.connect(src); db.row_factory = sqlite3.Row
out = {}
for r in db.execute('SELECT * FROM pieces ORDER BY n'):
    out[r['id']] = row_to_entry(r)
with open(dst, 'w', encoding='utf-8') as f:
    f.write(json.dumps(out, indent=2, ensure_ascii=False))   # même mise en forme que le fichier d'origine, sans retour final
print(f'{len(out)} entries -> {dst}')
