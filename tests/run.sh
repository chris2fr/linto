#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' 0 HUP INT TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_output() {
    expected=$1
    shift
    actual=$("$@") || fail "command failed: $*"
    [ "$actual" = "$expected" ] || {
        printf 'FAIL: %s\nexpected: <%s>\nactual:   <%s>\n' "$*" "$expected" "$actual" >&2
        exit 1
    }
}

cat > "$tmpdir/citations.qmd" <<'EOF'
First [@zeta; @alpha], then [@beta], then [@zeta] again.
EOF

assert_output '"zeta": 1
"alpha": 2
"beta": 3' \
    "$root/groups/bib/qmd2yml.sh" "$tmpdir/citations.qmd"
assert_output '"alpha": 1
"beta": 2
"zeta": 3' \
    "$root/groups/bib/qmd2yml.sh" --order-by key "$tmpdir/citations.qmd"
assert_output 'zeta
alpha
beta' \
    "$root/groups/bib/qmd2yml.sh" --format csv "$tmpdir/citations.qmd"
assert_output '"zeta": 10
"alpha": 11
"beta": 12' \
    "$root/groups/bib/qmd2yml.sh" --start 10 "$tmpdir/citations.qmd"

cat > "$tmpdir/references.bib" <<'EOF'
@article{first,
  year = {2020},
  title = {First title},
  author = {A. Author}
}

@book{second,
  zeta = {last},
  date = {2021},
  abstract = {Some text},
  author = {B. Author}
}
EOF

"$root/groups/bib/bib-order-props.sh" -i "$tmpdir/references.bib" >/dev/null
expected=$(cat <<'EOF'
@article{first,
  author = {A. Author},
  title = {First title},
  year = {2020}
}

@book{second,
  abstract = {Some text},
  author = {B. Author},
  date = {2021},
  zeta = {last}
}
EOF
)
actual=$(cat "$tmpdir/references.bib")
[ "$actual" = "$expected" ] || fail "default BibTeX field sorting"

cat > "$tmpdir/ordered.bib" <<'EOF'
@article{ordered,
  year = {2020},
  title = {Ordered},
  author = {A. Author},
  custom = {extra}
}
EOF
"$root/groups/bib/bib-order-props.sh" -i --order author --order title "$tmpdir/ordered.bib" >/dev/null
expected=$(cat <<'EOF'
@article{ordered,
  author = {A. Author},
  title = {Ordered},
  custom = {extra},
  year = {2020}
}
EOF
)
actual=$(cat "$tmpdir/ordered.bib")
[ "$actual" = "$expected" ] || fail "preferred BibTeX field order"

for form in separated repeated attached; do
  cp "$tmpdir/ordered.bib" "$tmpdir/$form.bib"
  case "$form" in
    separated) "$root/groups/bib/bib-order-props.sh" -i --order title --order author,date "$tmpdir/$form.bib" >/dev/null ;;
    repeated) "$root/groups/bib/bib-order-props.sh" -i --order title --order author --order date "$tmpdir/$form.bib" >/dev/null ;;
    attached) "$root/groups/bib/bib-order-props.sh" -i --order=title,author,date "$tmpdir/$form.bib" >/dev/null ;;
  esac
done
cmp -s "$tmpdir/separated.bib" "$tmpdir/repeated.bib" || fail "comma-separated order equivalence"
cmp -s "$tmpdir/separated.bib" "$tmpdir/attached.bib" || fail "attached order equivalence"

cat > "$tmpdir/unsupported.bib" <<'EOF'
@article{unsupported,
  title = {A multiline
    value},
  author = {A. Author}
}
EOF
cp "$tmpdir/unsupported.bib" "$tmpdir/unsupported.original"
if "$root/groups/bib/bib-order-props.sh" -i "$tmpdir/unsupported.bib" >/dev/null 2>&1; then
  fail "unsupported multiline field was accepted"
fi
cmp -s "$tmpdir/unsupported.bib" "$tmpdir/unsupported.original" || fail "unsupported input was modified"

cat > "$tmpdir/unterminated.bib" <<'EOF'
@article{broken,
  title = {Missing close}
EOF
cp "$tmpdir/unterminated.bib" "$tmpdir/unterminated.original"
if "$root/groups/bib/bib-order-props.sh" -i "$tmpdir/unterminated.bib" >/dev/null 2>&1; then
  fail "unterminated entry was accepted"
fi
cmp -s "$tmpdir/unterminated.bib" "$tmpdir/unterminated.original" || fail "unterminated input was modified"

assert_output 'base64decode
base64encode
countdown
eml2pdf
lorem
prettyprint
qrdecode
qrencode
stripaccents
timer
timezone
token
urldecode
urlencode
uuid' "$root/bin/linto" --list-commands utils
launch_output=$("$root/bin/linto-launch")
[ "$launch_output" = "$(printf 'Commands in group launch:\n  zed')" ] || fail "launch group wrapper output: $launch_output"

assert_output 'guillemets2quotes
pp
slug
zz' "$root/bin/linto" --list-shortcuts
if "$root/bin/linto" render --help >"$tmpdir/unqualified.out" 2>&1; then
    fail "command from a shortcuts-disabled group ran unqualified"
fi
assert_output 'Usage: linto quarto render [-h|--help] [--] [file.qmd ...]

Rebuild the bibliographies (linto bib bibyml2bib), then render each Quarto
document with `quarto render`. Without arguments, every *.qmd in the current
directory is rendered; .qmd files given as arguments are rendered instead.

Run it from the project root, where the .qmd files are.

Options:
  -h, --help  Show this help and exit.' \
    env LC_ALL=C "$root/bin/linto" quarto render --help

case "$("$root/bin/linto" --version)" in
    'linto '[v0-9]*) ;;
    *) fail "linto --version output" ;;
esac
[ "$("$root/bin/linto" -V)" = "$("$root/bin/linto" --version)" ] || fail "linto -V differs from --version"
if "$root/bin/linto" --version extra >/dev/null 2>&1; then
    fail "linto --version accepted an argument"
fi

index_help=$(LINTO_MDVIEWER=cat "$root/bin/linto" help)
case "$index_help" in
    *"  linto help bib"*) ;;
    *) fail "linto help does not list groups" ;;
esac
group_help=$(LINTO_MDVIEWER=cat "$root/bin/linto" help bib)
case "$group_help" in
    *"  linto help bib bib2json"*) ;;
    *) fail "linto help GROUP does not list commands" ;;
esac

python3 -m unittest discover -s "$root/tests" -p 'test_*.py'

echo 'All linto tests passed.'
