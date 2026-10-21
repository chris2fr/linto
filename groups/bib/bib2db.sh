#!/bin/sh
# linto-complete: flag --apply Write the changes (default: dry run)
# linto-complete: flag --prune Delete database entries absent from the BibTeX file
# linto-complete: flag --as-override Store a modified, non-overridden field as a "bibtex" override
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.db
set -eu

usage() {
  cat <<'EOF2'
Usage: bib2db.sh [--apply] [--prune] [--as-override] <fichier.bib> <fichier.db>

Compare a BibTeX file with the SQLite pieces table. By default, show the
changes field by field without writing anything.

Options :
  --apply        Apply the changes.
  --prune        Delete database rows whose keys are absent from the BibTeX file.
  --as-override  A value modified in the BibTeX file for a field that has no
                 override yet is stored as a "bibtex" override, the base value
                 being kept (default: it replaces the base value).
  -h, --help     Show this help and exit.

A field removed from the BibTeX file gets a null override (its base value is
kept). A field unknown to the schema becomes an override too.
EOF2
}

bib=
db=
flags=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --apply|--prune|--as-override) flags="$flags $1"; shift ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        if [ -z "$bib" ]; then bib=$1
        elif [ -z "$db" ]; then db=$1
        else echo 'bib2db: trop d’arguments' >&2; usage >&2; exit 2
        fi
        shift
      done
      ;;
    -*) echo "bib2db: option inconnue : $1" >&2; usage >&2; exit 2 ;;
    *)
      if [ -z "$bib" ]; then bib=$1
      elif [ -z "$db" ]; then db=$1
      else echo 'bib2db: trop d’arguments' >&2; usage >&2; exit 2
      fi
      shift
      ;;
  esac
done

[ -n "$bib" ] && [ -n "$db" ] || { usage >&2; exit 2; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck disable=SC2086
exec python3 "$script_dir/lib/bib2db.py" "$bib" "$db" $flags
