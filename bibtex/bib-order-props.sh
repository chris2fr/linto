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
for field_list in "${orders[@]}"; do
  IFS=',' read -r -a fields <<< "$field_list"
  for field in "${fields[@]}"; do
    field=${field//[[:space:]]/}
    [ -n "$field" ] || { echo "error: field names in --order cannot be empty" >&2; exit 2; }
    case "$(printf '%s' "$order_list" | tr '\\037' '\\n')" in
      *"$field"*)
        echo "error: duplicate field in --order: $field" >&2
        exit 2
        ;;
    esac
    if [ -n "$order_list" ]; then
      order_list+=$(printf '\\037')
    fi
    order_list+=$field
  done
done

fields_tmp=$(mktemp "${input}.fields.XXXXXX")
output_tmp=$(mktemp "${input}.tmp.XXXXXX")
trap 'rm -f -- "$fields_tmp" "$output_tmp"' EXIT

if ! awk -v order_list="$order_list" '
  BEGIN {
    RS = "\n"
    FS = ""
    order_count = split(order_list, preferred, sprintf("%c", 31))
    if (order_list == "") order_count = 0
    for (i = 1; i <= order_count; i++) field_rank[tolower(preferred[i])] = i
    in_entry = 0
    entry_count = 0
  }

  function flush_entry(    i, j, key, rank, temp_key, temp_line) {
    if (!in_entry) return
    if (entry_count == 0) {
      printf "%s\n", header
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
    printf "}\n"
  }

  /^[[:space:]]*$/ {
    if (!in_entry) print
    next
  }

  /^[[:space:]]*@[^[:space:]]+[[:space:]]*[{(]/ {
    flush_entry()
    in_entry = 1
    entry_count = 0
    header = $0
    next
  }

  in_entry && /^[[:space:]]*}[[:space:]]*[,;]?[[:space:]]*$/ {
    flush_entry()
    in_entry = 0
    next
  }

  in_entry {
    if (match($0, /^[[:space:]]*[^[:space:]=,]+[[:space:]]*=/)) {
      key = substr($0, RSTART, RLENGTH)
      sub(/^[[:space:]]*/, "", key)
      sub(/[[:space:]]*=$/, "", key)
      key = tolower(key)
      field_key[++entry_count] = key
      field_line[entry_count] = $0
    } else {
      # Keep multiline values attached to their field instead of reordering
      # their continuation lines as if they were separate fields.
      if (entry_count == 0) {
        printf "%s\n", $0
      } else {
        field_line[entry_count] = field_line[entry_count] "\n" $0
      }
    }
    next
  }

  { print }

  END {
    flush_entry()
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
