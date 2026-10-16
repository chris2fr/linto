#!/usr/bin/env bash
# Usage : json2bib.sh <entrée.json> <sortie.bib>
set -euo pipefail

json_in="${1:?Usage: $0 <entrée.json> <sortie.bib>}"
bib_out="${2:?Usage: $0 <entrée.json> <sortie.bib>}"

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
