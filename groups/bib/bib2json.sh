#!/bin/sh
# linto-complete: opt -o,--output *.json Output JSON file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the existing JSON in place (-i.bak keeps a backup)
# linto-complete: flag --as-override Store a modified, non-overridden field as a "bibtex" override
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.json
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o FICHIER.json | -i[.bak]] [--as-override]
          [--] [<fichier.bib>|-] [<existant.json>]

Répercute les entrées BibTeX sur les clés JSON existantes et crée une clé pour
chaque entrée BibTeX absente du JSON (champs au premier niveau). Champ déjà
surchargé dans "bibtex" : la surcharge est mise à jour; sinon la valeur du
premier niveau est mise à jour; champ disparu du BibTeX : surcharge null.
Chaque enregistrement commence par "key", qui répète le nom de sa propriété.

Sans fichier BibTeX (ou avec « - »), lit stdin. Sans JSON existant, on part
d'un JSON vide : toutes les entrées BibTeX sont créées.

Options :
  -o, --output FICHIER  Écrit le résultat dans FICHIER. Par défaut (ou avec
                        « -o - »), le résultat va sur stdout et la liste des
                        clés créées sur stderr.
  -i                    Remplace le JSON existant (requis; incompatible avec -o).
  -i.bak                Comme -i, en conservant une copie dans <existant.json>.bak.
  --as-override         Une valeur modifiée dans le BibTeX, pour un champ qui n'a
                        pas encore de surcharge, devient une surcharge "bibtex"
                        (la valeur du premier niveau est conservée).
  -h, --help            Affiche cette aide et quitte.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

in_place=0
as_override=
backup_suffix=
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --as-override) as_override=1; shift ;;
    -i) in_place=1; shift ;;
    -i.bak) in_place=1; backup_suffix=.bak; shift ;;
    -o|--output)
      [ "$#" -ge 2 ] || die_usage "l'option $1 requiert un argument"
      output=$2
      shift 2
      ;;
    --output=*) output=${1#*=}; shift ;;
    -o?*) output=${1#-o}; shift ;;
    --) shift; break ;;
    -?*) die_usage "option inconnue : $1" ;;
    *) break ;;
  esac
done
[ "$#" -le 2 ] || die_usage "au plus deux arguments sont attendus : fichier.bib et existant.json"
input=${1-}
json_in=${2-}

resolve_input "fichier BibTeX"
[ -z "$json_in" ] || require_file "fichier JSON" "$json_in"
[ "$output" != - ] || output=
if [ "$in_place" -eq 1 ]; then
  [ -n "$json_in" ] || die_usage "-i requiert un JSON existant en second argument"
  [ -z "$output" ] || die_usage "-i et -o/--output sont incompatibles"
  inplace_begin "$json_in"
  output=$output_tmp
elif [ -n "$json_in" ] && [ -n "$output" ] && [ "$json_in" -ef "$output" ]; then
  die_usage "entrée et sortie JSON sont le même fichier; utilisez -i"
fi

# prérequis, une seule fois : python3 -m pip install bibtexparser
python3 "$script_dir/lib/bib2json.py" "$input" "$json_in" "$output" "$as_override"

if [ "$in_place" -eq 1 ]; then
  inplace_commit "$json_in" "$backup_suffix"
fi
