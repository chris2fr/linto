#!/bin/sh
# linto-complete: opt -d,--outdir dir Output directory (default: current directory)
# linto-complete: opt -o,--output *.md Output file, or - for stdout (one PDF)
# linto-complete: opt --engine choices:auto,pdftotext,pdf2txt Text extractor (default: pdftotext if installed)
# linto-complete: flag --layout Keep the page layout of the text (pdftotext only)
# linto-complete: arg * *.pdf
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/pdf2md.py" "$@"
