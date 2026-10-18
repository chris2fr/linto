#!/usr/bin/env bash
# linto-complete: opt -o,--order value
# linto-complete: flag -i,-i.bak
# linto-complete: arg 1 *.bib
#
# bib-order-props.sh -- sort BibTeX fields within every supported entry.
#
# This formatter deliberately supports only one field per physical line with
# a single-line value. Unsupported syntax is rejected before replacing input.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [-i[.bak]] [-o|--order FIELD,...]... [-h|--help] [--] <file.bib>

Sort properties in every BibTeX entry. Properties are alphabetical by default.
Specify preferred properties with repeatable -o/--order options; commas may
separate multiple properties. Unspecified properties follow alphabetically.

Only entries with one single-line property per line are supported. The script
fails without changing the input if it encounters unsupported or ambiguous
entry syntax (including multiline values, comments or directives inside an
entry, duplicate fields, or unbalanced delimiters).

Options:
  -i                            Replace the input file in place.
  -i.bak                        Replace in place, saving the original as FILE.bak.
  -o, --order FIELD[,FIELD...]  Put these fields first, in the specified order.
  -h, --help                    Show this help and exit.

By default, the sorted result is written to standard output and the input is
left unchanged.
EOF
}

orders=()
in_place=0
backup_suffix=
input=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -i) in_place=1; shift ;;
    -i.bak) in_place=1; backup_suffix=.bak; shift ;;
    -o|--order)
      [ "$#" -ge 2 ] || { echo "error: $1 requires a field list" >&2; exit 2; }
      orders+=("$2")
      shift 2
      ;;
    --order=*) orders+=("${1#*=}"); shift ;;
    -o?*) orders+=("${1#-o}"); shift ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        [ -z "$input" ] || { echo "error: only one input file may be supplied" >&2; exit 2; }
        input=$1
        shift
      done
      ;;
    -* ) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      [ -z "$input" ] || { echo "error: only one input file may be supplied" >&2; exit 2; }
      input=$1
      shift
      ;;
  esac
done

if [ -z "$input" ]; then usage >&2; exit 2; fi
if [ ! -f "$input" ] || [ ! -r "$input" ]; then
  echo "$0: input file absent or unreadable: $input" >&2
  exit 1
fi
if [ "$in_place" -eq 1 ] && [ -L "$input" ]; then
  echo "$0: refusing to replace a symbolic link: $input" >&2
  exit 1
fi

order_list=
separator=$(printf '\037')
declare -A seen_fields=()
for field_list in "${orders[@]}"; do
  IFS=',' read -r -a fields <<< "$field_list"
  for field in "${fields[@]}"; do
    field=${field//[[:space:]]/}
    [ -n "$field" ] || { echo "error: field names in --order cannot be empty" >&2; exit 2; }
    normalized_field=${field,,}
    if [[ -v seen_fields[$normalized_field] ]]; then
      echo "error: duplicate field in --order: $field" >&2
      exit 2
    fi
    seen_fields[$normalized_field]=1
    [ -z "$order_list" ] || order_list+=$separator
    order_list+=$field
  done
done

output_tmp=$(mktemp "${input}.tmp.XXXXXX")
trap 'rm -f -- "$output_tmp"' EXIT

# Parse and validate the entire file before the temporary output is installed.
if ! awk -v order_list="$order_list" '
  BEGIN {
    order_count = split(order_list, preferred, sprintf("%c", 31))
    if (order_list == "") order_count = 0
    for (i = 1; i <= order_count; i++) field_rank[tolower(preferred[i])] = i
  }

  function fail(message) {
    printf "%s:%d: %s\n", FILENAME, FNR, message > "/dev/stderr"
    failed = 1
    exit 2
  }

  function validate_value(value,    i, ch, quote, escaped, braces, parens) {
    quote = ""; escaped = 0; braces = 0; parens = 0
    for (i = 1; i <= length(value); i++) {
      ch = substr(value, i, 1)
      if (escaped) { escaped = 0; continue }
      if (ch == "\\") { escaped = 1; continue }
      if (quote != "") {
        if (ch == quote) quote = ""
        continue
      }
      if (ch == "\"") { quote = ch; continue }
      if (ch == "{") braces++
      else if (ch == "}") braces--
      else if (ch == "(") parens++
      else if (ch == ")") parens--
      if (braces < 0 || parens < 0) return 0
    }
    return quote == "" && !escaped && braces == 0 && parens == 0
  }

  function flush_entry(    i, j, r1, r2, tmp) {
    if (!in_entry) return
    if (field_count == 0) fail("entry contains no fields")
    for (i = 1; i <= field_count; i++) {
      for (j = i + 1; j <= field_count; j++) {
        r1 = field_rank[field_key[i]]; r2 = field_rank[field_key[j]]
        if (r1 == 0) r1 = order_count + 1
        if (r2 == 0) r2 = order_count + 1
        if (r1 > r2 || (r1 == r2 && tolower(field_key[i]) > tolower(field_key[j]))) {
          tmp = field_key[i]; field_key[i] = field_key[j]; field_key[j] = tmp
          tmp = field_line[i]; field_line[i] = field_line[j]; field_line[j] = tmp
        }
      }
    }
    print header
    for (i = 1; i <= field_count; i++) {
      line = field_line[i]
      sub(/,[[:space:]]*$/, "", line)
      printf "%s%s\n", line, (i < field_count ? "," : "")
    }
    print closing
    delete field_key; delete field_line; delete field_seen
    field_count = 0
    in_entry = 0
  }

  /^[[:space:]]*$/ { if (!in_entry) print; next }

  /^[[:space:]]*@/ {
    if (in_entry) fail("new entry before previous entry closed")
    if ($0 !~ /^[[:space:]]*@[[:alnum:]_-]+[[:space:]]*[{(][^,]+,[[:space:]]*$/)
      fail("unsupported or malformed entry header")
    header = $0
    entry_type = tolower($0)
    sub(/^[[:space:]]*@/, "", entry_type)
    sub(/[[:space:]].*$/, "", entry_type)
    opening = ($0 ~ /\([^(]*,[[:space:]]*$/ ? "(" : "{")
    closing = (opening == "(" ? ")" : "}")
    in_entry = 1
    field_count = 0
    next
  }

  in_entry && /^[[:space:]]*[})][[:space:]]*[,;]?[[:space:]]*$/ {
    if ($0 !~ "^[[:space:]]*" closing "[[:space:]]*[,;]?[[:space:]]*$")
      fail("closing delimiter does not match entry header")
    flush_entry()
    next
  }

  in_entry {
    if ($0 ~ /^[[:space:]]*(%|#|@)/) fail("comments/directives inside entries are unsupported")
    if (!match($0, /^[[:space:]]*[[:alnum:]_-]+[[:space:]]*=/))
      fail("unsupported content inside entry; expected one field per line")
    key = substr($0, RSTART, RLENGTH)
    sub(/^[[:space:]]*/, "", key)
    sub(/[[:space:]]*=$/, "", key)
    key = tolower(key)
    if (key == entry_type) fail("field name conflicts with entry type")
    if (field_seen[key]++) fail("duplicate field: " key)
    value = substr($0, RSTART + RLENGTH)
    sub(/^[[:space:]]*/, "", value)
    if (!validate_value(value)) fail("multiline or unbalanced field value")
    field_key[++field_count] = key
    field_line[field_count] = $0
    next
  }

  { print }

  END {
    if (in_entry && !failed) fail("unterminated entry")
  }
' "$input" > "$output_tmp"; then
  echo "$0: refusing to replace input because parsing/validation failed: $input" >&2
  exit 1
fi

if [ ! -s "$output_tmp" ]; then
  echo "$0: no output generated for: $input" >&2
  exit 1
fi
if [ "$in_place" -eq 0 ]; then
  cat -- "$output_tmp"
  exit 0
fi

if [ -n "$backup_suffix" ]; then
  backup_path="$input$backup_suffix"
  [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || {
    echo "$0: refusing to overwrite existing backup: $backup_path" >&2
    exit 1
  }
  cp -p -- "$input" "$backup_path"
fi
chmod --reference="$input" "$output_tmp"
mv -f -- "$output_tmp" "$input"
printf '%s\n' "$input"
