#!/bin/sh
set -eu

usage() {
  cat <<EOF
Usage: $0 [-h|--help] [-j|--json entrée.json] [-o|--output sortie.json]
          [-i[.bak]] [--] <fichier.bib>

Injecte les entrées BibTeX dans le champ bibtex des clés JSON existantes et
crée une clé pour chaque entrée BibTeX absente du JSON (bibtex et frontmatter).

Options :
  -j, --json FICHIER    JSON d'entrée à compléter. Sans cette option, on part
                        d'un JSON vide : toutes les entrées BibTeX sont créées.
  -o, --output FICHIER  Écrit le résultat dans FICHIER. Sans cette option (ou
                        avec « -o - »), le résultat va sur stdout et la liste
                        des clés créées sur stderr.
  -i                    Remplace le JSON d'entrée (-j est requis; incompatible
                        avec -o).
  -i.bak                Comme -i, en conservant une copie dans <entrée.json>.bak.
  -h, --help            Affiche cette aide et quitte.
EOF
}

fail_usage() {
  echo "$0: $1" >&2
  usage >&2
  exit 2
}

in_place=0
backup_suffix=
json_in=
json_out=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -i) in_place=1; shift ;;
    -i.bak) in_place=1; backup_suffix=.bak; shift ;;
    -j|--json|-o|--output)
      [ "$#" -ge 2 ] || fail_usage "l'option $1 requiert un argument"
      case "$1" in -j|--json) json_in=$2 ;; *) json_out=$2 ;; esac
      shift 2
      ;;
    --json=*) json_in=${1#*=}; shift ;;
    --output=*) json_out=${1#*=}; shift ;;
    -j?*) json_in=${1#-j}; shift ;;
    -o?*) json_out=${1#-o}; shift ;;
    --) shift; break ;;
    -?*) fail_usage "option inconnue : $1" ;;
    *) break ;;
  esac
done

[ "$#" -eq 1 ] || fail_usage "un seul fichier BibTeX est attendu"
bib=$1
[ "$json_out" != - ] || json_out=

if [ "$in_place" -eq 1 ]; then
  [ -n "$json_in" ] || fail_usage "-i requiert -j/--json"
  [ -z "$json_out" ] || fail_usage "-i et -o/--output sont incompatibles"
  json_out=$json_in
fi
[ -f "$bib" ] && [ -r "$bib" ] || { echo "$0: fichier BibTeX absent ou illisible : $bib" >&2; exit 1; }
if [ -n "$json_in" ]; then
  [ -f "$json_in" ] && [ -r "$json_in" ] || { echo "$0: fichier JSON absent ou illisible : $json_in" >&2; exit 1; }
fi
if [ "$in_place" -eq 1 ] && [ -L "$json_in" ]; then
  echo "$0: refus de remplacer un lien symbolique : $json_in" >&2
  exit 1
fi
if [ "$in_place" -eq 0 ] && [ -n "$json_in" ] && [ -n "$json_out" ] && [ "$json_in" -ef "$json_out" ]; then
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

if not json_in:
    data = {}
else:
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

to_stdout = not json_out
if to_stdout:
    json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write('\n')
else:
    with open(json_out, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

if created:
    report = sys.stderr if to_stdout else sys.stdout
    print(f"Nouvelles clés créées depuis {bib_path} :", file=report)
    for key in created:
        print("  -", key, file=report)
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
