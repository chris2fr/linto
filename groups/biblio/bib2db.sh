#!/bin/sh
# linto-complete: flag --apply Write the changes (default: dry run)
# linto-complete: flag --add-columns Create TEXT columns for unknown BibTeX fields
# linto-complete: flag --prune Delete database entries absent from the BibTeX file
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.db
set -eu

usage() {
  cat <<'EOF'
Usage: bib2db.sh [--apply] [--add-columns] [--prune] <fichier.bib> <fichier.db>

Compare a BibTeX file with the SQLite pieces table. By default, show the
changes without writing anything.

Options :
  --apply        Apply the changes.
  --add-columns  Create TEXT columns for BibTeX fields that have no column.
  --prune        Delete database rows whose keys are absent from the BibTeX file.
  -h, --help     Show this help and exit.
EOF
}

bib=
db=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --apply|--add-columns|--prune)
      set -- "$@" "$1"
      break
      ;;
    --) shift; break ;;
    -*) echo "bib2db: option inconnue : $1" >&2; usage >&2; exit 2 ;;
    *) bib=$1; shift; break ;;
  esac
done

# Collect remaining positional arguments and supported flags without changing
# the required Python argument order (BibTeX path, then database path).
flags=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply|--add-columns|--prune)
      flags="$flags $1"
      shift
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        if [ -z "$db" ]; then db=$1; else echo 'bib2db: trop d’arguments' >&2; usage >&2; exit 2; fi
        shift
      done
      ;;
    -* ) echo "bib2db: option inconnue : $1" >&2; usage >&2; exit 2 ;;
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
