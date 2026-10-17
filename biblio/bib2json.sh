#!/bin/sh
set -eu

usage() {
  cat <<EOF
Usage: $0 [-h|--help] [-i[.bak]] <fichier.bib> <entrée.json> [sortie.json]

Avec -i, remplace le fichier JSON d'entrée. -i.bak conserve une copie
précédente dans un fichier suffixé par .bak.

Injecte les entrées BibTeX dans le champ bibtex des clés JSON existantes et
crée une clé pour chaque entrée BibTeX absente du JSON (bibtex et frontmatter).
EOF
}

in_place=0
backup_suffix=
case "${1-}" in
  -h|--help) usage; exit 0 ;;
  -i) in_place=1; shift ;;
  -i.bak) in_place=1; backup_suffix=.bak; shift ;;
  --) shift ;;
  -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$in_place" -eq 1 ]; then
  [ "$#" -eq 2 ] || { usage >&2; exit 2; }
else
  [ "$#" -eq 3 ] || { usage >&2; exit 2; }
fi

bib=$1
json_in=$2
if [ "$in_place" -eq 1 ]; then
  json_out=$json_in
else
  json_out=$3
fi
[ -f "$bib" ] && [ -r "$bib" ] || { echo "$0: fichier BibTeX absent ou illisible : $bib" >&2; exit 1; }
[ -f "$json_in" ] && [ -r "$json_in" ] || { echo "$0: fichier JSON absent ou illisible : $json_in" >&2; exit 1; }
if [ "$in_place" -eq 1 ] && [ -L "$json_in" ]; then
  echo "$0: refus de remplacer un lien symbolique : $json_in" >&2
  exit 1
fi
if [ "$in_place" -eq 0 ] && [ "$json_in" -ef "$json_out" ]; then
  echo "$0: entrée et sortie JSON sont le même fichier; utilisez -i" >&2
  exit 2
fi

if [ "$in_place" -eq 1 ]; then
  output_dir=$(CDPATH= cd -- "$(dirname -- "$json_out")" && pwd -P)
  output_tmp=$(mktemp "$output_dir/.bib2json.XXXXXX")
  trap 'rm -f -- "$output_tmp"' EXIT HUP INT TERM
  json_out=$output_tmp
fi

# une seule fois
# python3 -m pip install bibtexparser

# pip install bibtexparser

python3 - "$bib" "$json_in" "$json_out" <<'PY'
import json, sys, bibtexparser
from bibtexparser.bparser import BibTexParser

bib_path, json_in, json_out = sys.argv[1:4]

parser = BibTexParser(
    common_strings=True,
    ignore_nonstandard_types=False,   # accepte @misc, @article, ...
    homogenize_fields=False,          # conserve xtype, xtheme, xcounter...
)
parser.customization = None

with open(bib_path) as f:
    bib = bibtexparser.load(f, parser=parser)

by_id = {entry['ID']: entry for entry in bib.entries}

with open(json_in) as f:
    data = json.load(f)
if not isinstance(data, dict):
    raise SystemExit(f"Le JSON doit contenir un objet indexé par clé : {json_in}")

normalize = lambda entry: {k: v.replace('\\%', '%') if isinstance(v, str) else v
                           for k, v in entry.items() if k != 'ID'}

# Refresh entries already represented in JSON without disturbing their other fields.
for key, entry in data.items():
    if key in by_id:
        entry['bibtex'] = normalize(by_id[key])

# Add bibliography entries absent from JSON. These are new records, so their
# frontmatter starts as an independent copy of the normalized BibTeX fields.
created = []
for key, bib_entry in by_id.items():
    if key not in data:
        fields = normalize(bib_entry)
        data[key] = {'bibtex': fields, 'frontmatter': fields.copy()}
        created.append(key)

with open(json_out, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

if created:
    print(f"Nouvelles clés créées depuis {bib_path} :")
    for key in created:
        print("  -", key)
PY

if [ "$in_place" -eq 1 ]; then
  if [ -n "$backup_suffix" ]; then
    backup_path="$json_in$backup_suffix"
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || {
      echo "$0: refus d'écraser la sauvegarde existante : $backup_path" >&2
      exit 1
    }
    cp -p -- "$json_in" "$backup_path"
  fi
  chmod --reference="$json_in" "$output_tmp"
  mv -f -- "$output_tmp" "$json_in"
  trap - EXIT HUP INT TERM
fi
