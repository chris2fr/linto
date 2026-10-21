#!/bin/sh
# linto-complete: opt -o,--output *.db Output database (requires --apply)
# linto-complete: flag --apply Write the changes (default: dry run)
# linto-complete: flag --prune Delete database entries absent from the BibTeX file
# linto-complete: flag --as-override Store a modified, non-overridden field as a "bibtex" override
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.db
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [--apply [-o SORTIE.db]] [--prune]
          [--as-override] [--] <fichier.bib>|- <fichier.db>

Compare un fichier BibTeX avec la table SQLite « pieces ». Par défaut,
affiche les changements champ par champ sur stdout sans rien écrire.
Le BibTeX peut venir de stdin (« - »).

Options :
  --apply              Applique les changements au fichier .db.
  -o, --output FICHIER Avec --apply : copie le .db dans FICHIER et y applique
                       les changements, le .db d'entrée reste inchangé.
  --prune              Supprime les lignes dont la clé est absente du BibTeX.
  --as-override        Une valeur modifiée dans le BibTeX, pour un champ qui n'a
                       pas encore de surcharge, devient une surcharge "bibtex"
                       (la valeur de base est conservée; par défaut, elle
                       remplace la base).
  -h, --help           Affiche cette aide et quitte.

Un champ disparu du BibTeX reçoit une surcharge null (sa valeur de base est
conservée). Un champ inconnu du schéma devient aussi une surcharge.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

flags=
apply=0
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --apply) apply=1; flags="$flags $1"; shift ;;
    --prune|--as-override) flags="$flags $1"; shift ;;
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
[ "$#" -eq 2 ] || die_usage "deux arguments sont attendus : fichier.bib (ou -) et fichier.db"
input=$1
db=$2

resolve_input "fichier BibTeX"
require_file "fichier SQLite" "$db"
target=$db
if [ -n "$output" ]; then
  [ "$apply" -eq 1 ] || die_usage "-o/--output requiert --apply"
  [ ! "$db" -ef "$output" ] || die_usage "entrée et sortie sont le même fichier"
  cp -- "$db" "$output"
  target=$output
fi

# shellcheck disable=SC2086
exec python3 "$script_dir/lib/bib2db.py" "$input" "$target" $flags
