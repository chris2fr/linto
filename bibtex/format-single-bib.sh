#!/usr/bin/env bash
#
# format-single-bib.sh -- sort and normalize one @misc BibTeX entry.
#
# The input is expected to contain exactly one @misc entry, with its fields
# indented one per line. Blank lines and other non-indented lines are omitted.
#
# Usage: format-single-bib.sh [-h|--help] [--] <fichier.bib>

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [-h|--help] [--] <fichier.bib>

Trie les champs indentés d'une entrée @misc et remet les virgules en place.
Le fichier est remplacé uniquement si le traitement réussit.
EOF
}

# Parse the optional help and end-of-options marker.
case "${1-}" in
  -h|--help) usage; exit 0 ;;
  --) shift ;;
  -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

input=$1
if [ ! -f "$input" ] || [ ! -r "$input" ]; then
  echo "$0: fichier absent ou illisible : $input" >&2
  exit 1
fi
if [ -L "$input" ]; then
  echo "$0: refus de remplacer un lien symbolique : $input" >&2
  exit 1
fi

# This script is for one entry only; refuse inputs that would lose entries.
header_count=$(grep -c '^@misc' "$input" || true)
if [ "$header_count" -ne 1 ]; then
  echo "$0: attendu une seule entrée @misc (trouvé : $header_count) : $input" >&2
  exit 1
fi
header=$(grep -m 1 '^@misc' "$input")

# Keep temporary files beside the input so the final rename is atomic.
fields_tmp=$(mktemp "${input}.fields.XXXXXX")
output_tmp=$(mktemp "${input}.tmp.XXXXXX")
trap 'rm -f -- "$fields_tmp" "$output_tmp"' EXIT

# Sort fields consistently, independent of the user's locale.
if ! grep -E '^[[:space:]]+' "$input" | LC_ALL=C sort > "$fields_tmp"; then
  echo "$0: impossible de lire les champs de : $input" >&2
  exit 1
fi
if [ ! -s "$fields_tmp" ]; then
  echo "$0: aucun champ indenté trouvé : $input" >&2
  exit 1
fi

{
  printf '%s\n' "$header"
  # Ensure every field except the last has a comma, regardless of its original
  # position before sorting; the final field must not have a trailing comma.
  awk '{ sub(/,[[:space:]]*$/, ""); fields[NR] = $0 }
       END {
         for (i = 1; i <= NR; i++)
           printf "%s%s\n", fields[i], (i < NR ? "," : "")
       }' "$fields_tmp"
  printf '}\n'
} > "$output_tmp"

# Preserve the original file mode before replacing it with the completed file.
chmod --reference="$input" "$output_tmp"
mv -f -- "$output_tmp" "$input"
printf '%s\n' "$input"
