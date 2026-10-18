#!/bin/sh
set -eu

usage() {
  cat <<EOF
Usage: $0 [-h|--help] [-i[.bak]] <entrée.json>

Reconstruit un fichier BibTeX à partir du champ bibtex du JSON. La clé de
chaque entrée BibTeX est le nom de sa propriété dans le JSON (un éventuel ID
dans le champ bibtex est ignoré).
Par défaut, écrit le résultat sur stdout. -i remplace l'entrée JSON par le BibTeX;
-i.bak conserve une copie de l'entrée sous le nom <entrée.json>.bak.
EOF
}

in_place=0
backup_suffix=
case "${1-}" in
  -h|--help) usage; exit 0 ;;
  -i) in_place=1; shift ;;
  -i.bak) in_place=1; backup_suffix=.bak; shift ;;
  --) shift ;;
  -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
esac
if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

json_in=$1
[ -f "$json_in" ] && [ -r "$json_in" ] || {
  echo "$0: fichier JSON absent ou illisible : $json_in" >&2
  exit 1
}
if [ "$in_place" -eq 1 ] && [ -L "$json_in" ]; then
  echo "$0: refus de remplacer un lien symbolique : $json_in" >&2
  exit 1
fi

if [ "$in_place" -eq 1 ]; then
  output_dir=$(CDPATH= cd -- "$(dirname -- "$json_in")" && pwd -P)
  output_tmp=$(mktemp "$output_dir/.json2bib.XXXXXX")
  trap 'rm -f -- "$output_tmp"' EXIT HUP INT TERM
else
  output_tmp=
fi

jq -r 'to_entries[] | select(.value.bibtex == null) | .key' "$json_in" \
  | sed 's/^/Ignorée (pas de champ bibtex) : /' >&2

if [ "$in_place" -eq 1 ]; then
  exec_target=$output_tmp
else
  exec_target=/dev/stdout
fi

jq -r '
  to_entries[]
  | select(.value.bibtex != null)
  | .key as $citekey
  | .value.bibtex as $b
  | "@\($b.ENTRYTYPE){\($citekey),\n"
    + ([ $b | to_entries[]
         | select(.key | IN("ENTRYTYPE","ID") | not)
         | "  \(.key) = {\(.value | tostring | gsub("(?<!\\\\)%"; "\\%"))}" ]
       | join(",\n"))
    + "\n}\n"
' "$json_in" > "$exec_target"

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
