#!/bin/sh
# linto-complete: flag --apply Write the changes (default: dry run)
# linto-complete: flag --prune Delete database entries absent from the BibTeX file
# linto-complete: flag --as-override Store a modified, non-overridden field as a "bibtex" override
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.db
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [--apply] [--prune] [--as-override] [--]
          <fichier.bib> <fichier.db>

Compare un fichier BibTeX avec la table SQLite « pieces ». Par défaut,
affiche les changements champ par champ sans rien écrire.

Options :
  --apply        Applique les changements.
  --prune        Supprime les lignes dont la clé est absente du BibTeX.
  --as-override  Une valeur modifiée dans le BibTeX, pour un champ qui n'a pas
                 encore de surcharge, devient une surcharge "bibtex" (la valeur
                 de base est conservée; par défaut, elle remplace la base).
  -h, --help     Affiche cette aide et quitte.

Un champ disparu du BibTeX reçoit une surcharge null (sa valeur de base est
conservée). Un champ inconnu du schéma devient aussi une surcharge.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

flags=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --apply|--prune|--as-override) flags="$flags $1"; shift ;;
    --) shift; break ;;
    -?*) die_usage "option inconnue : $1" ;;
    *) break ;;
  esac
done
[ "$#" -eq 2 ] || die_usage "deux arguments sont attendus : fichier.bib et fichier.db"
require_file "fichier BibTeX" "$1"

# shellcheck disable=SC2086
exec python3 "$script_dir/lib/bib2db.py" "$1" "$2" $flags
