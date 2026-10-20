#!/bin/sh
# linto-complete: opt -o,--sortie dir Output directory for the PDFs
# linto-complete: opt --moteur choices:wkhtmltopdf,weasyprint Rendering engine (default: first one found)
# linto-complete: flag --force Overwrite existing PDFs
# linto-complete: flag --html-only Write the .html files without converting them
# linto-complete: flag --attachments Also extract the attachments
# linto-complete: arg 1 *.eml
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/lib/eml2pdf.py" "$@"
