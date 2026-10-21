#!/bin/sh
# linto-complete: arg 1 file
# Replace French guillemets with straight quotes, keeping a .bak backup.
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto quarto guillemets2quotes [-h|--help] [--] FILE

Replace French guillemets with straight double quotes in FILE.
A backup copy is kept with the suffix .bak.

Options:
  -h, --help  Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/../bib/lib/common.sh"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *) break ;;
  esac
done
[ "$#" -eq 1 ] || die_usage "exactly one %s is expected" "$(_ "file")"
[ -f "$1" ] || die "not a file: %s" "$1"

printf '%s\n' "$1"
sed -i.bak -e 's/« \| »/"/g' "$1"
