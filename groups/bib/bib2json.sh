#!/bin/sh
# linto-complete: opt -j,--json *.json Input JSON to complete
# linto-complete: opt -o,--output *.json Output JSON file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the -j file in place (-i.bak keeps a backup)
# linto-complete: flag --as-override Store a modified, non-overridden field as a "bibtex" override
# linto-complete: arg 1 *.bib
set -eu

usage() {
  cat <<EOF
Usage: $0 [-h|--help] [-j|--json entrée.json] [-o|--output sortie.json]
          [-i[.bak]] [--as-override] [--] <fichier.bib>

Répercute les entrées BibTeX sur les clés JSON existantes et crée une clé pour
chaque entrée BibTeX absente du JSON (champs au premier niveau). Champ déjà
surchargé dans "bibtex" : la surcharge est mise à jour; sinon la valeur du
premier niveau est mise à jour; champ disparu du BibTeX : surcharge null.
Chaque enregistrement commence par "key", qui répète le nom de sa propriété.

Options :
  -j, --json FICHIER    JSON d'entrée à compléter. Sans cette option, on part
                        d'un JSON vide : toutes les entrées BibTeX sont créées.
  -o, --output FICHIER  Écrit le résultat dans FICHIER. Sans cette option (ou
                        avec « -o - »), le résultat va sur stdout et la liste
                        des clés créées sur stderr.
  -i                    Remplace le JSON d'entrée (-j est requis; incompatible
                        avec -o).
  -i.bak                Comme -i, en conservant une copie dans <entrée.json>.bak.
  --as-override         Une valeur modifiée dans le BibTeX, pour un champ qui n'a
                        pas encore de surcharge, devient une surcharge "bibtex"
                        (la valeur du premier niveau est conservée).
  -h, --help            Affiche cette aide et quitte.
EOF
}

fail_usage() {
  echo "$0: $1" >&2
  usage >&2
  exit 2
}

in_place=0
as_override=
backup_suffix=
json_in=
json_out=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --as-override) as_override=1; shift ;;
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

# prérequis, une seule fois : python3 -m pip install bibtexparser
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
python3 "$script_dir/lib/bib2json.py" "$bib" "$json_in" "$json_out" "$as_override"

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
