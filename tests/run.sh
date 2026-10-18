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
    "$root/groups/quarto/citations.sh" "$tmpdir/citations.qmd"
assert_output '"alpha": 1
"beta": 2
"zeta": 3' \
    "$root/groups/quarto/citations.sh" --order-by key "$tmpdir/citations.qmd"
assert_output '"zeta"
"alpha"
"beta"' \
    "$root/groups/quarto/citations.sh" --format csv "$tmpdir/citations.qmd"
assert_output '"zeta": 10
"alpha": 11
"beta": 12' \
    "$root/groups/quarto/citations.sh" --start 10 "$tmpdir/citations.qmd"

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

"$root/groups/biblio/bib-order-props.sh" "$tmpdir/references.bib" >/dev/null
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
"$root/groups/biblio/bib-order-props.sh" --order author --order title "$tmpdir/ordered.bib" >/dev/null
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
    separated) "$root/groups/biblio/bib-order-props.sh" -o title -o author,date "$tmpdir/$form.bib" >/dev/null ;;
    repeated) "$root/groups/biblio/bib-order-props.sh" -o title -o author -o date "$tmpdir/$form.bib" >/dev/null ;;
    attached) "$root/groups/biblio/bib-order-props.sh" -otitle,author,date "$tmpdir/$form.bib" >/dev/null ;;
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
if "$root/groups/biblio/bib-order-props.sh" "$tmpdir/unsupported.bib" >/dev/null 2>&1; then
  fail "unsupported multiline field was accepted"
fi
cmp -s "$tmpdir/unsupported.bib" "$tmpdir/unsupported.original" || fail "unsupported input was modified"

cat > "$tmpdir/unterminated.bib" <<'EOF'
@article{broken,
  title = {Missing close}
EOF
cp "$tmpdir/unterminated.bib" "$tmpdir/unterminated.original"
if "$root/groups/biblio/bib-order-props.sh" "$tmpdir/unterminated.bib" >/dev/null 2>&1; then
  fail "unterminated entry was accepted"
fi
cmp -s "$tmpdir/unterminated.bib" "$tmpdir/unterminated.original" || fail "unterminated input was modified"

assert_output 'prettyprint
stripaccents
timezone' "$root/bin/linto" --list-commands utils
launch_output=$("$root/bin/linto-launch")
[ "$launch_output" = "$(printf 'Commands in group launch:\n  zed')" ] || fail "launch group wrapper output: $launch_output"

shortcuts=$("$root/bin/linto" --list-shortcuts)
case "$shortcuts" in
    *quarto-render*) fail "shortcut listed for a group with shortcuts disabled" ;;
esac
case "$shortcuts" in
    *bibyml2bib*) ;;
    *) fail "shortcut missing for a group with shortcuts enabled" ;;
esac
if "$root/bin/linto" render --help >"$tmpdir/unqualified.out" 2>&1; then
    fail "command from a shortcuts-disabled group ran unqualified"
fi
assert_output 'Usage: render.sh [-h|--help] [fichier.qmd ...]

Régénère les bibliographies (bibyml2bib.sh) puis rend chaque document
Quarto avec `quarto render`. Sans argument, tous les *.qmd du dossier
courant sont rendus ; les fichiers .qmd passés en argument sont rendus
à la place.

Doit être lancé depuis la racine du projet, où se trouvent les fichiers .qmd.

Options:
  -h, --help   Affiche cette aide et quitte.' \
    "$root/bin/linto" quarto render --help

python3 -m unittest discover -s "$root/tests" -p 'test_*.py'

echo 'All linto tests passed.'
