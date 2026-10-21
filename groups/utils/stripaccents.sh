#!/bin/sh
# linto-complete: opt -f,--file file Rename a file to its slug
# linto-complete: opt -d,--dir dir Rename a directory to its slug
# linto-complete: opt --min value Minimum slug length
# linto-complete: opt --max value Maximum slug length
# linto-complete: arg * value
# Transliterate UTF-8 text to an ASCII slug, or rename a file to a slugified
# filename. File mode preserves the extension and refuses to overwrite a target.

usage() {
  _ "$(cat <<'EOF'
Usage: linto utils stripaccents [-h|--help] [--min LENGTH] [--max LENGTH] [TEXT ...]
       linto utils stripaccents [-h|--help] [--min LENGTH] [--max LENGTH] -f|--file FILE
       linto utils stripaccents [-h|--help] [--min LENGTH] [--max LENGTH] -d|--dir DIR

Without --file or --dir, reads text from stdin (or from TEXT arguments when
stdin is a terminal) and writes normalized slugs to stdout.
With --file, slugifies only the part before the final dot and preserves that
suffix (including the dot). With --dir, renames DIR in its parent directory.
Neither mode overwrites an existing destination.

Options:
  -f, --file FILE   Rename FILE to its slugified filename.
  -d, --dir DIR     Rename DIR to its slugified directory name.
  --min LENGTH      Minimum slug length; shorter slugs are padded with "_" (default: 1).
  --max LENGTH      Maximum slug length; truncation prefers a word boundary (default: 48).
  -h, --help        Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/../../lib/common.sh"

MINLEN=1
MAXLEN=48
FILE=
DIR=
TEXT=

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -f|--file)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      [ -z "$FILE" ] || die_usage "%s may only be specified once" "--file"
      FILE=$2
      shift 2
      ;;
    -d|--dir)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      [ -z "$DIR" ] || die_usage "%s may only be specified once" "--dir"
      DIR=$2
      shift 2
      ;;
    --min)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      MINLEN=$2
      shift 2
      ;;
    --max)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      MAXLEN=$2
      shift 2
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        TEXT="${TEXT}${TEXT:+ }$1"
        shift
      done
      ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *)
      TEXT="${TEXT}${TEXT:+ }$1"
      shift
      ;;
  esac
done

case "$MINLEN" in
  ''|*[!0-9]*) die_usage "%s must be a positive integer" "--min" ;;
esac
case "$MAXLEN" in
  ''|*[!0-9]*) die_usage "%s must be a positive integer" "--max" ;;
esac
[ "$MINLEN" -ge 1 ] && [ "$MAXLEN" -ge 1 ] || die_usage "--min and --max must be at least 1"
[ "$MINLEN" -le "$MAXLEN" ] || die_usage "--min cannot be greater than --max"

slugify() {
  iconv -f UTF-8 -t ASCII//TRANSLIT//IGNORE \
    | sed -e 's/\(.*\)/\L\1/' \
          -e 's/[^a-z0-9]\+/_/g' \
          -e 's/^_//' -e 's/_$//' \
    | awk -v min="$MINLEN" -v max="$MAXLEN" '
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
          while (length(s) < min)
            s = s "_"
          print s
        }'
}

if [ -n "$FILE" ] || [ -n "$DIR" ]; then
  if [ -n "$FILE" ] && [ -n "$DIR" ]; then
    die_usage "do not combine --file and --dir"
  fi
  if [ -n "$TEXT" ]; then
    die_usage "do not combine --file/--dir with text arguments"
  fi

  if [ -n "$FILE" ]; then
    if [ ! -f "$FILE" ]; then
      die "not a regular file: %s" "$FILE"
    fi
    source_path=$FILE
    name=$(basename -- "$FILE")
  else
    if [ ! -d "$DIR" ]; then
      die "not a directory: %s" "$DIR"
    fi
    source_path=$DIR
    name=$(basename -- "$DIR")
  fi

  parent_dir=$(dirname -- "$source_path")
  if [ -n "$FILE" ]; then
    case "$name" in
      *.*)
        # Slugify only the part before the final dot; preserve the rest exactly.
        stem=${name%.*}
        extension=.${name##*.}
        ;;
      *)
        stem=$name
        extension=
        ;;
    esac
  else
    stem=$name
    extension=
  fi

  slug=$(printf '%s\n' "$stem" | slugify) || exit 1
  if [ -z "$slug" ]; then
    die "name produces an empty slug: %s" "$source_path"
  fi

  target=$parent_dir/$slug$extension
  if [ "$target" = "$source_path" ]; then
    echo "$source_path"
    exit 0
  fi
  if [ -e "$target" ]; then
    die "destination already exists: %s" "$target"
  fi

  if mv -n -- "$source_path" "$target"; then
    # Some mv implementations return success even when -n declined to move.
    if [ -e "$source_path" ]; then
      die "destination already exists: %s" "$target"
    fi
    echo "$target"
  else
    die "could not rename '%s' to '%s'" "$source_path" "$target"
  fi
  exit 0
fi

if [ -n "$TEXT" ]; then
  printf '%s\n' "$TEXT" | slugify
elif [ ! -t 0 ]; then
  slugify
else
  die_usage "provide text, pipe input, or use --file FILE / --dir DIR"
fi
