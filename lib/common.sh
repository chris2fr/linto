# common.sh -- helpers shared by the shell commands of every group (POSIX sh, sourced).
#
# Usage, from groups/GROUP/<script>.sh, after defining usage():
#   . "$(dirname -- "$0")/../../lib/common.sh"
#
# Provides:
#   _ TEXT                translated TEXT (English source; see lib/i18n.py)
#   prog, script_dir      script name without ".sh"; its physical directory
#   die MSG...            "prog: MSG" on stderr, exit 1 (runtime error)
#   die_usage MSG...      "prog: MSG" and usage on stderr, exit 2 (usage error)
#   require_file KIND F   exit 1 unless F is a readable regular file
#   require_cmd CMD       exit 1 unless CMD is installed
#   resolve_input KIND    input: the file named by $input, or stdin (/dev/stdin)
#                         when $input is empty or "-"; sets from_stdin
#   check_inplace         validate -i against $input and $output
#   redirect_output       send stdout to $output (unless empty or "-")
#   inplace_begin F       refuse a symlink; create a temporary file next to F
#                         (sets output_tmp, removed on exit)
#   inplace_commit F SUF  keep F as F<SUF> when SUF is set, then replace F
#                         with output_tmp, preserving its mode

prog=$(basename -- "$0" .sh)
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

# Translate TEXT with the catalog for the current language (lib/i18n.py).
# English needs no catalog, so no Python is started for it.
_() {
  case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
    ''|C|C.*|POSIX|en|en_*|en.*) printf '%s' "$1" ;;
    *) python3 "$script_dir/../../lib/i18n.py" "$1" ;;
  esac
}

# die MSG [ARG...]: MSG is a printf format (translated), ARGs fill its %s.
die() {
  fmt=$(_ "$1")
  shift
  printf "%s: $fmt\n" "$prog" "$@" >&2
  exit 1
}

die_usage() {
  fmt=$(_ "$1")
  shift
  printf "%s: $fmt\n" "$prog" "$@" >&2
  usage >&2
  exit 2
}

# require_file KIND FILE: KIND is a translated noun, e.g. "BibTeX file".
require_file() {
  [ -f "$2" ] && [ -r "$2" ] || die "%s missing or unreadable: %s" "$(_ "$1")" "$2"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "%s is required" "$1"
}

resolve_input() {
  case "${input-}" in
    ''|-)
      [ ! -t 0 ] || die_usage "no %s: give a file or provide stdin" "$(_ "$1")"
      input=/dev/stdin
      from_stdin=1
      ;;
    *)
      require_file "$1" "$input"
      from_stdin=0
      ;;
  esac
}

check_inplace() {
  if [ "${in_place:-0}" -eq 1 ]; then
    [ -z "${output-}" ] || die_usage "-i and -o/--output are incompatible"
    [ "$from_stdin" -eq 0 ] || die_usage "-i needs an input file (not stdin)"
  fi
}

redirect_output() {
  case "${output-}" in
    ''|-) ;;
    *)
      if [ "$from_stdin" -eq 0 ] && [ "$input" -ef "$output" ]; then
        die_usage "input and output are the same file; use -i"
      fi
      exec >"$output"
      ;;
  esac
}

inplace_begin() {
  [ ! -L "$1" ] || die "refusing to replace a symbolic link: %s" "$1"
  output_dir=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd -P)
  output_tmp=$(mktemp "$output_dir/.$prog.XXXXXX")
  trap 'rm -f -- "$output_tmp"' EXIT HUP INT TERM
}

inplace_commit() {
  if [ -n "$2" ]; then
    backup_path="$1$2"
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] ||
      die "refusing to overwrite the existing backup: %s" "$backup_path"
    cp -p -- "$1" "$backup_path"
  fi
  chmod --reference="$1" "$output_tmp"
  mv -f -- "$output_tmp" "$1"
  trap - EXIT HUP INT TERM
}
