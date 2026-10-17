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

assert_output 'prettyprint
stripaccents
timezone' "$root/bin/linto" --list-commands utils
launch_output=$("$root/bin/linto-launch")
[ "$launch_output" = "$(printf 'Commands in group launch:\n  zed')" ] || fail "launch group wrapper output: $launch_output"

python3 -m unittest discover -s "$root/tests" -p 'test_*.py'

echo 'All linto tests passed.'
