#!/bin/sh
# linto-complete: opt -o,--output-file *.bib
# linto-complete: arg 1 *.bib
# linto-complete: arg 2 *.yml,*.yaml
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
generator="$script_dir/lib/generer-bib.py"

# Explicit arguments use the generic single-file interface.
if [ "$#" -gt 0 ]; then
    exec python3 "$generator" "$@"
fi

# Preserve the legacy batch workflow used by the Quarto renderer.
found=0
for yml_file in _pieces-*.yml; do
    [ -f "$yml_file" ] || continue
    found=1
    output_base="${yml_file#_}"
    output_base="${output_base%.yml}"
    echo "$yml_file"
    python3 "$generator" fr.bib "$yml_file" --output-file "$output_base.bib"
done

if [ "$found" -eq 0 ]; then
    echo "error: no _pieces-*.yml files found; provide BIBTEX_FILE YAML_FILE" >&2
    exit 1
fi
