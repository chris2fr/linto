#!/usr/bin/env bash
# linto-complete: opt -w,--width value Maximum output width in columns
# linto-complete: opt -f,--font choices:classic,outlined Font to render with
# linto-complete: arg * value
#
# Render text as big block ASCII art.

set -euo pipefail

CELL_W=6
ROWS=5

usage() {
  _ "$(cat <<'EOF'
Usage: linto utils prettyprint [-w COLS] [-f FONT] [-h] [TEXT...]

Render TEXT as 5-line-high block ASCII art, wrapped to the terminal width.

Options:
  -w, --width COLS   Force the maximum output width, in columns.
  -f, --font FONT    Select a font (classic or outlined; default: classic).
  -h, --help         Show this help and exit.

With no TEXT arguments the input is read from standard input.
EOF
)"
  echo
}

. "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
font_name=classic
FONT_TABLE=

declare -A FONT=()

load_font() {
  local font_file="$script_dir/lib/fonts/$1"
  [[ -r $font_file ]] || die_usage "unknown or unreadable font: %s" "$1"
  FONT_TABLE=$(<"$font_file")
  FONT=()
  local line key
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    key=${line:0:1}
    FONT["$key"]=${line:2}
    FONT["${key^^}"]=${line:2}
    FONT["${key,,}"]=${line:2}
  done <<<"$FONT_TABLE"
}

# Glyph files use KEY:row1|row2|row3|row4|row5. Dots are blank pixels,
# lookups are case-insensitive, and unknown characters render as blank cells.
load_font "$font_name"

glyph() {
  printf '%s' "${FONT[$1]:-      |      |      |      |      }"
}

wrap_words() {
  local text=$1 max=$2
  local cap=$(( (max - 2 + 1) / (CELL_W + 1) ))
  (( cap < 1 )) && cap=1

  local -a words=()
  read -r -a words <<<"$text"

  local -a row=() ; local rowlen=0
  local w wlen
  for w in "${words[@]}"; do
    wlen=${#w}
    if (( wlen > cap )); then
      if (( rowlen > 0 )); then printf '%s\n' "${row[*]}"; row=(); rowlen=0; fi
      while (( wlen > cap )); do
        printf '%s\n' "${w:0:cap}"
        w=${w:cap}
        wlen=${#w}
      done
      row=("$w"); rowlen=$wlen
    elif (( rowlen == 0 )); then
      row=("$w"); rowlen=$wlen
    elif (( rowlen + 1 + wlen <= cap )); then
      row+=("$w"); rowlen=$(( rowlen + 1 + wlen ))
    else
      printf '%s\n' "${row[*]}"
      row=("$w"); rowlen=$wlen
    fi
  done
  (( rowlen > 0 )) && printf '%s\n' "${row[*]}"
}

render_row() {
  local rowtext=$1 r ch g
  for (( r = 1; r <= ROWS; r++ )); do
    local out='  '
    for (( i = 0; i < ${#rowtext}; i++ )); do
      ch=${rowtext:i:1}
      g=$(glyph "$ch" | cut -d'|' -f"$r")
      g=${g//./ }
      printf -v g '%-*s' "$CELL_W" "${g:0:CELL_W}"
      out+=$g' '
    done
    printf '%s\n' "${out% }"
  done
}

render() {
  local text=$1 max=$2 line
  local first=1
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    if (( first )); then
      first=0
    else
      echo
    fi
    render_row "$line"
  done < <(wrap_words "$text" "$max")
}

main() {
  local max=''
  local -a args=()

  while (( $# )); do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -w|--width)
        shift
        [[ ${1:-} =~ ^[0-9]+$ ]] || die_usage "option %s needs a column count" "-w"
        max=$1 ;;
      -f|--font)
        shift
        [[ -n ${1:-} ]] || die_usage "option %s needs a font name" "-f"
        font_name=$1 ;;
      --font=*) font_name=${1#*=} ;;
      --) shift; args+=("$@"); break ;;
      -*) die_usage "unknown option: %s" "$1" ;;
      *) args+=("$1") ;;
    esac
    shift
  done

  load_font "$font_name"
  echo

  if [[ -z $max ]]; then
    max=$(tput cols 2>/dev/null || true)
    [[ $max =~ ^[0-9]+$ ]] || max=${COLUMNS:-80}
  fi
  (( max < CELL_W + 1 )) && max=$(( CELL_W + 1 ))

  if (( ${#args[@]} )); then
    render "${args[*]}" "$max"
  else
    while IFS= read -r line; do
      [[ -z ${line//[[:space:]]/} ]] && { echo; continue; }
      render "$line" "$max"
    done
  fi
}

main "$@"
echo
