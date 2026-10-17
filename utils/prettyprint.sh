#!/usr/bin/env bash
#
# prettyprint.sh -- render text as big block ASCII art.
#
# Each character is drawn in a 5-line-high by 6-character-wide cell, so a
# line of input becomes five rows of output. Words are wrapped so that each
# output line fits the available terminal width (detected automatically, or
# forced with -w). Words too long for one line are split across lines.
#
# Usage:
#   prettyprint.sh [-w COLS] [-h] [TEXT...]
#
# Options:
#   -w, --width COLS   Force the maximum output width, in columns.
#   -h, --help         Show this help and exit.
#
# The TEXT arguments are joined with single spaces. With no arguments the
# text is read from standard input and rendered line by line.
# Exit status is 0 on success, 2 on a usage error.

set -euo pipefail

# Cell geometry: 5 rows high, 6 columns wide, one blank column between cells.
CELL_W=6
ROWS=5

usage() {
  cat <<'EOF'
Usage: prettyprint.sh [-w COLS] [-h] [TEXT...]

Render TEXT as 5-line-high block ASCII art, wrapped to the terminal width.

Options:
  -w, --width COLS   Force the maximum output width, in columns.
  -h, --help         Show this help and exit.

With no TEXT arguments the input is read from standard input.
EOF
}

# ---------------------------------------------------------------------------
# Font.
#
# The font lives in the heredoc below: one glyph per line, "X:rows", where X
# is the key character and `rows` is five '|'-separated rows. Each row is 6
# characters wide using '.' or spaces for blanks and any other printable
# character (#, |, /, ...) for ink. Lookups are case-insensitive, so lower-case
# letters reuse the upper-case glyphs. Unknown characters blank out.
# ---------------------------------------------------------------------------
read -r -d '' FONT_TABLE <<'FONT' || true
A:. ### |#   # |##### |#   # |#   #
B:##### |#   # |####  |#   # |#####
C:.#### |#     |#     |#     |.####
D:####  |#   # |#   # |#   # |####
E:##### |#     |####  |#     |#####
F:##### |#     |####  |#     |#
G:.#### |#     |# ### |#   # |.###.
H:#   # |#   # |##### |#   # |#   #
I:.###. |. # . |. # . |. # . |.###.
J:..### |... # |... # |#  #  |.##.
K:#   # |#  #  |###   |#  #  |#   #
L:#     |#     |#     |#     |#####
M:#   # |## ## |# # # |#   # |#   #
N:#   # |##  # |# # # |#  ## |#   #
O:.###. |#   # |#   # |#   # |.###.
P:##### |#   # |##### |#     |#
Q:.###. |#   # |#   # |#  ## |.####
R:##### |#   # |##### |#  #  |#   #
S:.#### |#     |.###. |    # |####.
T:##### |. # . |. # . |. # . |. # .
U:#   # |#   # |#   # |#   # |.###.
V:#   # |#   # |#   # |. # . |. # .
W:#   # |#   # |# # # |## ## |#   #
X:#   # |. # . |. # . |. # . |#   #
Y:#   # |. # . |. # . |. # . |. # .
Z:##### |   #  |. # . |#     |#####
0:.###. |#   # |#   # |#   # |.###.
1:.. #  |. ##  |.. #  |.. #  |.####
2:.###  |#   # |.  #  |. #   |#####
3:##### |    # |.###. |    # |####.
4:#   # |#   # |##### |    # |    #
5:##### |#     |####  |    # |####.
6:. ### |#     |##### |#   # |.####
7:##### |    # |.  #  |. #   |. #
8:.###. |#   # |.###. |#   # |.###.
9:##### |#   # |##### |    # |.###.
.:     |     |     |     |  #
,:     |     |     |  #  | #
!:  #  |  #  |  #  |     |  #
?: ### |#   # |   # |     |   #
-:     |     |#####|     |
_:     |     |     |     |#####
':. #  |. #  |     |     |
":. # #|. # #|     |     |
::     |     |     |. #  |
;:     |     |. #  |     | #
(:   # |  #  |  #  |  #  |   #
):  #  |   # |   # |   # |  #
/:    #|   # |  #  | #   |#
\:#     |  #  |   # |    #|
+:     |  #  |#####|  #  |
=:     |#####|     |#####|
*:#   #|  #  |#####|  #  |#   #
$: ####|# ## |#### |## # |####
&:  #  | #   |  #  | # # |  # #
#:#   #|#####|#   #|#####|#   #
@:##    |# ##  |# ##  |#     | ##
%:#   #|   # |  #  | #   |#   #
^:  #  | # # |#   #|     |
~:     | ##  |   # |  ## |
|:#   # |#   # |#   # |#   # |#   #
<:   # |  #  | #   |  #  |   #
>: #   |  #  |   # |  #  | #
[:.###. |#     |#     |#     |.###.
]:.###. |    # |    # |    # |.###.
{:. ### |  ##  | ##   |  ##  |. ###
}: ###. |  ##  |   ## |  ##  | ###.
`:. #  |  #  |     |     |
FONT

# Build an associative lookup from the font table: key -> rows, so that font
# keys which are regex metacharacters (\ / $ # . * ? [ ] :) need no escaping.
#
# The format is exactly "X:rows" -- a single key character, a colon, then the
# five '|'-separated rows -- so punctuation keys such as ':' parse unambiguously.
declare -A FONT=()
while IFS= read -r line; do
  [[ -z $line ]] && continue
  key=${line:0:1}
  FONT["$key"]=${line:2}
  FONT["${key^^}"]=${line:2}
  FONT["${key,,}"]=${line:2}
done <<<"$FONT_TABLE"

# glyph ROW_CHAR -> the five rows of ROW_CHAR, '|'-separated.
glyph() {
  printf '%s' "${FONT[$1]:-      |      |      |      |      }"
}

# ---------------------------------------------------------------------------
# Wrapping: turn the input line into rows of glyphs that each fit MAX_WIDTH.
# Rows are filled word by word; a word wider than MAX_WIDTH is split so no
# output ever exceeds the width.
# ---------------------------------------------------------------------------
wrap_words() {
  local text=$1 max=$2
  # Cells are CELL_W+1 columns wide except the last (no trailing gutter).
  # Include the two-column left margin in the available width. Each glyph
  # takes CELL_W columns; the one-column gutter follows all but the last glyph.
  local cap=$(( (max - 2 + 1) / (CELL_W + 1) ))
  (( cap < 1 )) && cap=1

  local -a words=()
  read -r -a words <<<"$text"

  local -a row=() ; local rowlen=0
  local w wlen i piece
  for w in "${words[@]}"; do
    wlen=${#w}
    if (( wlen > cap )); then            # split an over-long word
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

# ---------------------------------------------------------------------------
# Rendering: draw one wrapped row of glyph cells as five output lines.
# ---------------------------------------------------------------------------
render_row() {
  local rowtext=$1 r ch g
  for (( r = 1; r <= ROWS; r++ )); do
    local out='  '
    for (( i = 0; i < ${#rowtext}; i++ )); do
      ch=${rowtext:i:1}
      g=$(glyph "$ch" | cut -d'|' -f"$r")
      # Normalise blanks and pad/trim to CELL_W.
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
      echo            # blank line between blocks
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
        [[ ${1:-} =~ ^[0-9]+$ ]] || { echo "prettyprint.sh: -w needs a column count" >&2; exit 2; }
        max=$1 ;;
      --) shift; args+=("$@"); break ;;
      -*) echo "prettyprint.sh: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *)  args+=("$1") ;;
    esac
    shift
  done

  # Resolve width: -w wins, else the terminal, else a sane default.
  if [[ -z $max ]]; then
    max=$(tput cols 2>/dev/null || true)
    [[ $max =~ ^[0-9]+$ ]] || max=${COLUMNS:-80}
  fi
  (( max < CELL_W + 1 )) && max=$(( CELL_W + 1 ))

  if (( ${#args[@]} )); then
    render "${args[*]}" "$max"
  else
    local line
    while IFS= read -r line; do
      [[ -z ${line//[[:space:]]/} ]] && { echo; continue; }
      render "$line" "$max"
    done
  fi
}

echo
main "$@"
