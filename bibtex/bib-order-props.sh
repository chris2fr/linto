#!/usr/bin/env bash
#
# bib-order-props.sh -- sort BibTeX fields within every entry.
#
# Fields are sorted alphabetically by default. Repeated --order options define
# preferred field order; any other fields follow alphabetically.
#
# Usage: bib-order-props.sh [-o FIELD,...]... [-h|--help] [--] <file.bib>

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [-o|--order FIELD,...]... [-h|--help] [--] <file.bib>

Sorts the properties of every BibTeX entry in the file. By default, properties
are sorted alphabetically. Preferred properties can be supplied as comma-separated
lists and/or repeated options; all remaining properties are sorted alphabetically.

Options:
  -o, --order FIELD[,FIELD...]  Put these fields first, in the specified order.
  -h, --help                    Show this help and exit.

Equivalent examples:
  $0 -o title -o author,date references.bib
  $0 -o title -o author -o date references.bib
  $0 -oauthor,title,date references.bib
EOF
}

orders=()
input=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -o|--order)
      [ "$#" -ge 2 ] || { echo "error: $1 requires a field list" >&2; exit 2; }
      orders+=("$2")
      shift 2
      ;;
    --order=*)
      orders+=("${1#*=}")
      shift
      ;;
    -o?*)
      orders+=("${1#-o}")
      shift
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        [ -z "$input" ] || { echo "error: only one input file may be supplied" >&2; exit 2; }
        input=$1
        shift
      done
      ;;
    -* )
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      [ -z "$input" ] || { echo "error: only one input file may be supplied" >&2; exit 2; }
      input=$1
      shift
      ;;
  esac
done

if [ -z "$input" ]; then
  usage >&2
  exit 2
fi
if [ ! -f "$input" ] || [ ! -r "$input" ]; then
  echo "$0: input file absent or unreadable: $input" >&2
  exit 1
fi
if [ -L "$input" ]; then
  echo "$0: refusing to replace a symbolic link: $input" >&2
  exit 1
fi

# Pass the preferred keys as a unit-separator-delimited string. BibTeX field
# names cannot contain this character.
order_list=
declare -A seen_fields=()
separator=$(printf '\037')
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
    if [ -n "$order_list" ]; then
      order_list+=$separator
    fi
    order_list+=$field
  done
done

fields_tmp=$(mktemp "${input}.fields.XXXXXX")
output_tmp=$(mktemp "${input}.tmp.XXXXXX")
trap 'rm -f -- "$fields_tmp" "$output_tmp"' EXIT

if ! awk -v order_list="$order_list" '
  BEGIN {
    RS = "\\n"
    FS = ""
    order_count = split(order_list, preferred, sprintf("%c", 31))
    if (order_list == "") order_count = 0
    for (i = 1; i <= order_count; i++) field_rank[tolower(preferred[i])] = i
    in_entry = 0
    entry_count = 0
    failed = 0
  }

  function flush_entry(    i, j, rank_i, rank_j, temp_key, temp_line) {
    if (!in_entry) return
    if (entry_count == 0) {
      fail("entry has no fields")
      return
    }

    # Sort records by preferred-key rank first, then case-insensitive key name.
    for (i = 1; i <= entry_count; i++) {
      for (j = i + 1; j <= entry_count; j++) {
        rank_i = field_rank[field_key[i]]
        rank_j = field_rank[field_key[j]]
        if (rank_i == 0) rank_i = order_count + 1
        if (rank_j == 0) rank_j = order_count + 1
        if (rank_i > rank_j || (rank_i == rank_j && tolower(field_key[i]) > tolower(field_key[j]))) {
          temp_key = field_key[i]; field_key[i] = field_key[j]; field_key[j] = temp_key
          temp_line = field_line[i]; field_line[i] = field_line[j]; field_line[j] = temp_line
        }
      }
    }

    printf "%s\n", header
    for (i = 1; i <= entry_count; i++) {
      line = field_line[i]
      sub(/,[[:space:]]*$/, "", line)
      printf "%s%s\n", line, (i < entry_count ? "," : "")
    }
    printf "%s\\n", closing
    delete field_key
    delete field_line
    entry_count = 0
  }

  function fail(message) {
    printf "%s:%d: %s\\n", FILENAME, FNR, message > "/dev/stderr"
    failed = 1
    exit 2
  }

  /^[[:space:]]*$/ {
    if (!in_entry) print
    next
  }

  /^[[:space:]]*@/ {
    if (in_entry) fail("new entry started before previous entry closed")
    if ($0 !~ /^[[:space:]]*@[[:alnum:]_-]+[[:space:]]*[{(][^,]+,[[:space:]]*$/)
      fail("unsupported or malformed entry header")
    header = $0
    entry_type = tolower($0)
    sub(/^[[:space:]]*@/, "", entry_type)
    sub(/[[:space:]].*$/, "", entry_type)
    entry_key = $0
    sub(/^[^({]*[{(][[:space:]]*/, "", entry_key)
    sub(/,[[:space:]]*$/, "", entry_key)
    if (entry_key == "") fail("entry has no citation key")
    in_entry = 1
    entry_count = 0
    closing = (header ~ /[(][^)]*$/ ? ")" : "}")
    next
  }

  in_entry && $0 ~ /^[[:space:]]*[})][[:space:]]*[,;]?[[:space:]]*$/ {
    if ($0 !~ "^[[:space:]]*" closing "[[:space:]]*[,;]?[[:space:]]*$")
      fail("entry closes with a delimiter that does not match its header")
    flush_entry()
    in_entry = 0
    next
  }

  in_entry {
    if ($0 ~ /^[[:space:]]*[%#]/ || $0 ~ /^[[:space:]]*@/) {
      fail("comments and directives inside entries are not supported")
    }
    if (match($0, /^[[:space:]]*[^[:space:]=,]+[[:space:]]*=/)) {
      key = substr($0, RSTART, RLENGTH)
      sub(/^[[:space:]]*/, "", key)
      sub(/[[:space:]]*=$/, "", key)
      key = tolower(key)
      if (key == tolower(entry_type)) fail("field name conflicts with entry type")
      if (field_seen[key]++) fail("duplicate field: " key)
      field_key[++entry_count] = key
      field_line[entry_count] = $0
      value = substr($0, RSTART + RLENGTH)
      value_balance = 0
      quote = ""
      escaped = 0
      scan_value(value)
      field_balance[entry_count] = value_balance
      field_quote[entry_count] = quote
      field_escaped[entry_count] = escaped
    } else if (entry_count > 0) {
      field_line[entry_count] = field_line[entry_count] "\\n" $0
      scan_value($0)
      field_balance[entry_count] = value_balance
      field_quote[entry_count] = quote
      field_escaped[entry_count] = escaped
    } else if ($0 !~ /^[[:space:]]*$/) {
      fail("unrecognized content before first field")
    }
    next
  }

  { print }

  function scan_value(text,    i, ch) {
    for (i = 1; i <= length(text); i++) {
      ch = substr(text, i, 1)
      if (escaped) { escaped = 0; continue }
      if (ch == "\\\\") { escaped = 1; continue }
      if (quote != "") {
        if (ch == quote) quote = ""
        continue
      }
      if (ch == "\"") { quote = ch; continue }
      if (ch == "{") value_balance++
      else if (ch == "}") value_balance--
      else if (ch == "(") value_balance++
      else if (ch == ")") value_balance--
      if (value_balance < 0) fail("unbalanced delimiter in field value")
    }
    if (quote != "" || value_balance != 0 || escaped)
      return
    if (text ~ /,[[:space:]]*$/) return
  }

  END {
    if (in_entry && !failed) {
      fail("unterminated entry")
    }
  }
' "$input" > "$output_tmp"; then
  echo "$0: failed to parse BibTeX entries in: $input" >&2
  exit 1
fi

if [ ! -s "$output_tmp" ]; then
  echo "$0: no output generated for: $input" >&2
  exit 1
fi

chmod --reference="$input" "$output_tmp"
mv -f -- "$output_tmp" "$input"
printf '%s\n' "$input"
