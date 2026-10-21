#!/usr/bin/env bash
# linto-complete: opt --order value Fields to put first (comma-separated, repeatable)
# linto-complete: opt -o,--output *.bib Output BibTeX file (default: stdout)
# linto-complete: flag -i,-i.bak Replace the file in place (-i.bak keeps a backup)
# linto-complete: arg 1 *.bib
#
# bib-order-props.sh -- sort BibTeX fields within every supported entry.
#
# This formatter deliberately supports only one field per physical line with
# a single-line value. Unsupported syntax is rejected before replacing input.

set -euo pipefail

usage() {
  cat <<EOF
Usage: linto bib $prog [-h|--help] [-o FICHIER | -i[.bak]] [--order CHAMP,...]...
          [--] [<fichier.bib>|-]

Trie les propriétés de chaque entrée BibTeX, par ordre alphabétique par
défaut. Les options répétables --order désignent les propriétés à placer en
premier; des virgules peuvent séparer plusieurs propriétés. Les autres
suivent par ordre alphabétique.

Seules les entrées à une propriété par ligne, avec une valeur sur une seule
ligne, sont prises en charge. Le script échoue sans modifier l'entrée devant
une syntaxe non prise en charge ou ambiguë (valeur sur plusieurs lignes,
commentaire ou directive dans une entrée, champ en double, délimiteurs
déséquilibrés).

Sans fichier d'entrée (ou avec « - »), lit stdin.

Options :
  -o, --output FICHIER     Écrit le résultat dans FICHIER (défaut : stdout).
  -i                       Remplace le fichier d'entrée.
  -i.bak                   Comme -i, en conservant l'original dans FICHIER.bak.
  --order CHAMP[,CHAMP...] Place ces champs en premier, dans cet ordre.
  -h, --help               Affiche cette aide et quitte.

Par défaut, l'entrée reste inchangée.
EOF
}

. "$(dirname -- "$0")/lib/common.sh"

orders=()
in_place=0
backup_suffix=
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -i) in_place=1; shift ;;
    -i.bak) in_place=1; backup_suffix=.bak; shift ;;
    --order)
      [ "$#" -ge 2 ] || die_usage "l'option $1 requiert une liste de champs"
      orders+=("$2")
      shift 2
      ;;
    --order=*) orders+=("${1#*=}"); shift ;;
    -o|--output)
      [ "$#" -ge 2 ] || die_usage "l'option $1 requiert un argument"
      output=$2
      shift 2
      ;;
    --output=*) output=${1#*=}; shift ;;
    -o?*) output=${1#-o}; shift ;;
    --) shift; break ;;
    -?*) die_usage "option inconnue : $1" ;;
    *) break ;;
  esac
done
[ "$#" -le 1 ] || die_usage "un seul fichier BibTeX est attendu"
input=${1-}

resolve_input "fichier BibTeX"
check_inplace

order_list=
separator=$(printf '\037')
declare -A seen_fields=()
for field_list in "${orders[@]}"; do
  IFS=',' read -r -a fields <<< "$field_list"
  for field in "${fields[@]}"; do
    field=${field//[[:space:]]/}
    [ -n "$field" ] || die_usage "les noms de champs de --order ne peuvent pas être vides"
    normalized_field=${field,,}
    if [[ -v seen_fields[$normalized_field] ]]; then
      die_usage "champ en double dans --order : $field"
    fi
    seen_fields[$normalized_field]=1
    [ -z "$order_list" ] || order_list+=$separator
    order_list+=$field
  done
done

if [ "$in_place" -eq 1 ]; then
  inplace_begin "$input"
else
  output_tmp=$(mktemp)
  trap 'rm -f -- "$output_tmp"' EXIT HUP INT TERM
fi

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
  die "analyse ou validation échouée, entrée inchangée : $input"
fi

[ -s "$output_tmp" ] || die "aucune sortie générée pour : $input"
if [ "$in_place" -eq 0 ]; then
  redirect_output
  cat -- "$output_tmp"
  exit 0
fi

inplace_commit "$input" "$backup_suffix"
printf '%s\n' "$input"
