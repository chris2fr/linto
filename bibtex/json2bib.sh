#!/bin/sh
set -eu

usage() {
  cat <<EOF
Usage: $0 [-h|--help] <entrée.json> <sortie.bib>

Reconstruit un fichier BibTeX à partir du champ bibtex du JSON.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  --) shift ;;
  -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
esac
if [ "$#" -ne 2 ]; then
  usage >&2
  exit 2
fi

json_in=$1
bib_out=$2

jq -r 'to_entries[] | select(.value.bibtex == null) | .key' "$json_in" \
  | sed 's/^/Ignorée (pas de champ bibtex) : /' >&2

jq -r '
  to_entries[]
  | select(.value.bibtex != null)
  | .value.bibtex as $b
  | "@\($b.ENTRYTYPE){\($b.ID),\n"
    + ([ $b | to_entries[]
         | select(.key | IN("ENTRYTYPE","ID") | not)
         | "  \(.key) = {\(.value | tostring | gsub("(?<!\\\\)%"; "\\%"))}" ]
       | join(",\n"))
    + "\n}\n"
' "$json_in" > "$bib_out"
