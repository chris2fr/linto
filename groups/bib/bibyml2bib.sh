#!/bin/sh
# linto-complete: opt -o,--output-file *.bib Output BibTeX file
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.yml,*.yaml
set -eu

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o|--output-file FICHIER.bib]
          <source.bib> <correspondance.yml>
       linto bib $prog

Construit un fichier BibTeX numéroté à partir d'une source BibTeX et d'une
correspondance YAML clé -> numéro.

Sans argument, traite chaque _pieces-*.yml du répertoire courant avec fr.bib et
écrit pieces-*.bib (flux utilisé par « linto render »).

Options :
  -o, --output-file FICHIER   Fichier BibTeX de sortie.
  -h, --help                  Affiche cette aide et quitte.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

generator="$script_dir/lib/generer-bib.py"

case "${1-}" in
  -h|--help) usage; exit 0 ;;
esac

# Des arguments explicites utilisent l'interface générique à un fichier.
if [ "$#" -gt 0 ]; then
  exec python3 "$generator" "$@"
fi

# Flux historique par lots, utilisé par le rendu Quarto.
found=0
for yml_file in _pieces-*.yml; do
  [ -f "$yml_file" ] || continue
  found=1
  output_base="${yml_file#_}"
  output_base="${output_base%.yml}"
  echo "$yml_file"
  python3 "$generator" fr.bib "$yml_file" --output-file "$output_base.bib"
done

[ "$found" -eq 1 ] || die "aucun fichier _pieces-*.yml; fournir <source.bib> <correspondance.yml>"
