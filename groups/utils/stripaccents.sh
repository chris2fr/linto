#!/bin/sh
# Transliterate UTF-8 text to an ASCII slug, or rename a file to a slugified
# filename. File mode preserves the extension and refuses to overwrite a target.

usage() {
  cat <<EOF
Usage: $0 [-h|--help] [--min LENGTH] [--max LENGTH] [TEXT ...]
       $0 [-h|--help] [--min LENGTH] [--max LENGTH] -f|--file FILE
       $0 [-h|--help] [--min LENGTH] [--max LENGTH] -d|--dir DIR

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
EOF
}

MINLEN=1
MAXLEN=48
FILE=
DIR=
TEXT=

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -f|--file)
      if [ "$#" -lt 2 ]; then
        echo "$0: $1 requires a file path" >&2
        usage >&2
        exit 2
      fi
      if [ -n "$FILE" ]; then
        echo "$0: --file may only be specified once" >&2
        exit 2
      fi
      FILE=$2
      shift 2
      ;;
    -d|--dir)
      if [ "$#" -lt 2 ]; then
        echo "$0: $1 requires a directory path" >&2
        usage >&2
        exit 2
      fi
      if [ -n "$DIR" ]; then
        echo "$0: --dir may only be specified once" >&2
        exit 2
      fi
      DIR=$2
      shift 2
      ;;
    --min)
      if [ "$#" -lt 2 ]; then
        echo "$0: --min requires a length" >&2
        usage >&2
        exit 2
      fi
      MINLEN=$2
      shift 2
      ;;
    --max)
      if [ "$#" -lt 2 ]; then
        echo "$0: --max requires a length" >&2
        usage >&2
        exit 2
      fi
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
    -* )
      echo "$0: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      TEXT="${TEXT}${TEXT:+ }$1"
      shift
      ;;
  esac
done

case "$MINLEN" in
  ''|*[!0-9]*) echo "$0: --min must be a positive integer" >&2; exit 2 ;;
esac
case "$MAXLEN" in
  ''|*[!0-9]*) echo "$0: --max must be a positive integer" >&2; exit 2 ;;
esac
if [ "$MINLEN" -lt 1 ] || [ "$MAXLEN" -lt 1 ]; then
  echo "$0: --min and --max must be at least 1" >&2
  exit 2
fi
if [ "$MINLEN" -gt "$MAXLEN" ]; then
  echo "$0: --min cannot be greater than --max" >&2
  exit 2
fi

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
    echo "$0: do not combine --file and --dir" >&2
    exit 2
  fi
  if [ -n "$TEXT" ]; then
    echo "$0: do not combine --file/--dir with text arguments" >&2
    exit 2
  fi

  if [ -n "$FILE" ]; then
    if [ ! -f "$FILE" ]; then
      echo "$0: not a regular file: $FILE" >&2
      exit 1
    fi
    source_path=$FILE
    name=$(basename -- "$FILE")
  else
    if [ ! -d "$DIR" ]; then
      echo "$0: not a directory: $DIR" >&2
      exit 1
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
    echo "$0: name produces an empty slug: $source_path" >&2
    exit 1
  fi

  target=$parent_dir/$slug$extension
  if [ "$target" = "$source_path" ]; then
    echo "$source_path"
    exit 0
  fi
  if [ -e "$target" ]; then
    echo "$0: destination already exists: $target" >&2
    exit 1
  fi

  if mv -n -- "$source_path" "$target"; then
    # Some mv implementations return success even when -n declined to move.
    if [ -e "$source_path" ]; then
      echo "$0: destination already exists: $target" >&2
      exit 1
    fi
    echo "$target"
  else
    echo "$0: could not rename '$source_path' to '$target'" >&2
    exit 1
  fi
  exit 0
fi

if [ -n "$TEXT" ]; then
  printf '%s\n' "$TEXT" | slugify
elif [ ! -t 0 ]; then
  slugify
else
  echo "$0: provide text, pipe input, or use --file FILE / --dir DIR" >&2
  usage >&2
  exit 2
fi
