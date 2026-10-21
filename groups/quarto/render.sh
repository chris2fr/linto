#!/bin/sh
# linto-complete: arg * *.qmd,*.md
# Rebuild the bibliographies, then render Quarto documents. Run it from the
# project root, where the .qmd files live.
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto quarto render [-h|--help] [--] [file.qmd ...]

Rebuild the bibliographies (linto bib bibyml2bib), then render each Quarto
document with `quarto render`. Without arguments, every *.qmd in the current
directory is rendered; .qmd files given as arguments are rendered instead.

Run it from the project root, where the .qmd files are.

Options:
  -h, --help  Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/../../lib/common.sh"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *) break ;;
  esac
done

# bibyml2bib exits 1 both when there are no mappings (expected) and on real
# failures, so only the "no mappings" diagnostic, in the C locale, is ignored.
bib_status=0
bib_output=$(LC_ALL=C "$script_dir/../bib/bibyml2bib.sh" 2>&1) || bib_status=$?
if [ "$bib_status" -ne 0 ]; then
  case "$bib_output" in
    *'no _pieces-*.yml file; give'*) ;;
    *) printf '%s\n' "$bib_output" >&2; exit "$bib_status" ;;
  esac
fi
[ -z "$bib_output" ] || [ "$bib_status" -ne 0 ] || printf '%s\n' "$bib_output"

if [ "$#" -eq 0 ]; then
  set -- *.qmd
  [ -f "$1" ] || die "no .qmd file to render"
fi

for i do
  echo "$i"
  quarto render "$i"
done
