import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "groups" / "bib" / "lib"

ENTRIES = {
    "k1": {
        "key": "k1", "ENTRYTYPE": "report", "year": "2020", "title": "T",
        "author": "A", "zeta": "z", "alpha": "a", "markdown": "text",
        "bibtex": {"year": "2021", "note": "n"},
    }
}


def run(script, *args, config=None):
    env = dict(os.environ, LC_ALL="C")
    env["XDG_CONFIG_HOME"] = config or "/nonexistent"
    env["HOME"] = "/nonexistent"
    return subprocess.run(
        [sys.executable, str(LIB / script), *map(str, args)],
        capture_output=True, text=True, env=env, check=True,
    )


class FieldOrderTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.json = self.tmp / "in.json"
        self.json.write_text(json.dumps(ENTRIES), encoding="utf-8")
        self.db = self.tmp / "t.db"

    def roundtrip(self, config=None):
        run("json2db.py", self.json, self.db, config=config)
        out = self.tmp / "out.json"
        run("db2json.py", self.db, out, config=config)
        return json.loads(out.read_text(encoding="utf-8"))["k1"]

    def test_no_field_order_column(self):
        run("json2db.py", self.json, self.db)
        conn = sqlite3.connect(self.db)
        cols = [c[1] for c in conn.execute("PRAGMA table_info(pieces)")]
        conn.close()
        self.assertNotIn("field_order", cols)

    def test_alphabetical_by_default(self):
        entry = self.roundtrip()
        self.assertEqual(
            list(entry),
            ["key", "ENTRYTYPE", "alpha", "author", "title", "year", "zeta", "markdown", "bibtex"],
        )
        self.assertEqual(list(entry["bibtex"]), ["note", "year"])

    def test_configured_order(self):
        cfg = self.tmp / "cfg"
        (cfg / "linto").mkdir(parents=True)
        (cfg / "linto" / "config.yml").write_text(
            "configdata:\n  bib:\n    field-order: [title, year, author]\n", encoding="utf-8"
        )
        entry = self.roundtrip(config=str(cfg))
        self.assertEqual(
            list(entry),
            ["key", "ENTRYTYPE", "title", "year", "author", "alpha", "zeta", "markdown", "bibtex"],
        )

    def test_bib_export_follows_order(self):
        run("json2db.py", self.json, self.db)
        bib = self.tmp / "o.bib"
        run("db2bib.py", self.db, bib)
        names = [l.split("=")[0].strip() for l in bib.read_text(encoding="utf-8").splitlines() if " = " in l]
        self.assertEqual(names, ["author", "note", "title", "year", "xdbmeta"])


if __name__ == "__main__":
    unittest.main()
