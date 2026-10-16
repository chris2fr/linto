#!/bin/sh
# Transliterate UTF-8 to ASCII, then normalize to a lowercase slug:
# lowercase, non [a-z0-9] runs -> "_", no leading/trailing "_".
# Result is limited to ${1:-48} characters; if the limit falls inside a word
# and there is a "_" before it, cut back to just before that "_".
# Usage: stripaccents.sh [max_length]   (reads stdin, writes stdout)
MAXLEN=${1:-48}

iconv -f UTF-8 -t ASCII//TRANSLIT//IGNORE \
  | sed -e 's/\(.*\)/\L\1/' \
        -e 's/[^a-z0-9]\+/_/g' \
        -e 's/^_//' -e 's/_$//' \
  | awk -v max="$MAXLEN" '
      {
        s = $0
        if (length(s) > max) {
          head = substr(s, 1, max)
          p = 0
          for (i = 1; i <= max; i++)
            if (substr(head, i, 1) == "_")
              p = i
          if (p > 0)
            s = substr(head, 1, p - 1)
          else
            s = head
        }
        print s
      }'
