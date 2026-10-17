#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

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
    "$root/quarto/citations.sh" "$tmpdir/citations.qmd"
assert_output '"alpha": 1
"beta": 2
"zeta": 3' \
    "$root/quarto/citations.sh" --order-by key "$tmpdir/citations.qmd"
assert_output '"zeta"
"alpha"
"beta"' \
    "$root/quarto/citations.sh" --format csv "$tmpdir/citations.qmd"
assert_output '"zeta": 10
"alpha": 11
"beta": 12' \
    "$root/quarto/citations.sh" --start 10 "$tmpdir/citations.qmd"

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

"$root/bibtex/bib-order-props.sh" "$tmpdir/references.bib" >/dev/null
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
"$root/bibtex/bib-order-props.sh" --order author --order title "$tmpdir/ordered.bib" >/dev/null
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
    separated) "$root/bibtex/bib-order-props.sh" -o title -o author,date "$tmpdir/$form.bib" >/dev/null ;;
    repeated) "$root/bibtex/bib-order-props.sh" -o title -o author -o date "$tmpdir/$form.bib" >/dev/null ;;
    attached) "$root/bibtex/bib-order-props.sh" -otitle,author,date "$tmpdir/$form.bib" >/dev/null ;;
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
if "$root/bibtex/bib-order-props.sh" "$tmpdir/unsupported.bib" >/dev/null 2>&1; then
  fail "unsupported multiline field was accepted"
fi
cmp -s "$tmpdir/unsupported.bib" "$tmpdir/unsupported.original" || fail "unsupported input was modified"

cat > "$tmpdir/unterminated.bib" <<'EOF'
@article{broken,
  title = {Missing close}
EOF
cp "$tmpdir/unterminated.bib" "$tmpdir/unterminated.original"
if "$root/bibtex/bib-order-props.sh" "$tmpdir/unterminated.bib" >/dev/null 2>&1; then
  fail "unterminated entry was accepted"
fi
cmp -s "$tmpdir/unterminated.bib" "$tmpdir/unterminated.original" || fail "unterminated input was modified"

assert_output 'prettyprint
stripaccents
timezone' "$root/bin/linto" --list-commands utils
launch_output=$("$root/bin/linto-launch")
[ "$launch_output" = "$(printf 'Commands in group launch:\n  zed')" ] || fail "launch group wrapper output: $launch_output"

python3 -m unittest discover -s "$root/tests" -p 'test_*.py'

echo 'All linto tests passed.'
