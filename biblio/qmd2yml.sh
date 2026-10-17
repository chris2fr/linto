#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
Usage: qmd2yml.sh [OPTIONS] FILE.qmd

Extract unique Pandoc-style citation keys from a Quarto/Markdown file and
write them as a numbered YAML mapping or a one-column CSV.

Options:
  --order-by ORDER   Order keys by appearance (default) or key.
  --format FORMAT    Output yml (default) or csv.
  --start NUMBER     First YAML number (default: 1).
  -h, --help         Show this help and exit.

Examples:
  qmd2yml.sh report.qmd
  qmd2yml.sh --order-by key --format csv report.qmd
  qmd2yml.sh --start 10 report.qmd
EOF
}

order_by=appearance
format=yml
start=1
file=

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --order-by)
            [ "$#" -ge 2 ] || { echo "error: --order-by requires a value" >&2; exit 2; }
            order_by=$2
            shift 2
            ;;
        --order-by=*)
            order_by=${1#*=}
            shift
            ;;
        --format)
            [ "$#" -ge 2 ] || { echo "error: --format requires a value" >&2; exit 2; }
            format=$2
            shift 2
            ;;
        --format=*)
            format=${1#*=}
            shift
            ;;
        --start)
            [ "$#" -ge 2 ] || { echo "error: --start requires a value" >&2; exit 2; }
            start=$2
            shift 2
            ;;
        --start=*)
            start=${1#*=}
            shift
            ;;
        --)
            shift
            break
            ;;
        -* )
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            [ -z "$file" ] || { echo "error: only one input file may be supplied" >&2; exit 2; }
            file=$1
            shift
            ;;
    esac
done

if [ -z "$file" ] || [ "$#" -ne 0 ]; then
    usage >&2
    exit 2
fi
if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "error: '$file' is not a readable file" >&2
    exit 1
fi
case "$order_by" in
    appearance|key) ;;
    *) echo "error: --order-by must be 'appearance' or 'key'" >&2; exit 2 ;;
esac
case "$format" in
    yml|yaml|csv) ;;
    *) echo "error: --format must be 'yml' or 'csv'" >&2; exit 2 ;;
esac
case "$start" in
    ''|*[!0-9]*) echo "error: --start must be a non-negative integer" >&2; exit 2 ;;
esac

# Extract keys from citation clusters such as [@key] and [@key1; @key2].
# Preserve first-seen order unless key sorting was requested.
grep -oE '\[@[^]]+\]' "$file" |
    sed -E 's/^\[@|\]$//g; s/[;,][[:space:]]*/\n/g; s/@//g; s/^[[:space:]]+//; s/[[:space:]]+$//' |
    awk -v order_by="$order_by" '
        NF && !seen[$0]++ { keys[++count] = $0 }
        END {
            if (order_by == "key") {
                for (i = 1; i <= count; i++) {
                    for (j = i + 1; j <= count; j++) {
                        if (keys[i] > keys[j]) {
                            tmp = keys[i]; keys[i] = keys[j]; keys[j] = tmp
                        }
                    }
                }
            }
            for (i = 1; i <= count; i++) print keys[i]
        }
    ' |
    awk -v format="$format" -v number="$start" '
        format == "csv" {
            value = $0
            gsub(/"/, """", value)
            print "\"" value "\""
            next
        }
        {
            key = $0
            gsub(/\\/, "\\\\", key)
            gsub(/"/, "\\\"", key)
            printf "\"%s\": %d\n", key, number++
        }
    '
