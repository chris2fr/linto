# common.sh -- helpers shared by the bib group scripts (POSIX sh, sourced).
#
# Usage, from groups/bib/<script>.sh, after defining usage():
#   . "$(dirname -- "$0")/lib/common.sh"
#
# Provides:
#   prog, script_dir      script name without ".sh"; its physical directory
#   die MSG...            "prog: MSG" on stderr, exit 1 (runtime error)
#   die_usage MSG...      "prog: MSG" and usage on stderr, exit 2 (usage error)
#   require_file KIND F   exit 1 unless F is a readable regular file
#   require_cmd CMD       exit 1 unless CMD is installed
#   inplace_begin F       refuse a symlink; create a temporary file next to F
#                         (sets output_tmp, removed on exit)
#   inplace_commit F SUF  keep F as F<SUF> when SUF is set, then replace F
#                         with output_tmp, preserving its mode

prog=$(basename -- "$0" .sh)
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

die() {
  printf '%s: %s\n' "$prog" "$*" >&2
  exit 1
}

die_usage() {
  printf '%s: %s\n' "$prog" "$*" >&2
  usage >&2
  exit 2
}

require_file() {
  [ -f "$2" ] && [ -r "$2" ] || die "$1 absent ou illisible : $2"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 est requis"
}

inplace_begin() {
  [ ! -L "$1" ] || die "refus de remplacer un lien symbolique : $1"
  output_dir=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd -P)
  output_tmp=$(mktemp "$output_dir/.$prog.XXXXXX")
  trap 'rm -f -- "$output_tmp"' EXIT HUP INT TERM
}

inplace_commit() {
  if [ -n "$2" ]; then
    backup_path="$1$2"
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] ||
      die "refus d'écraser la sauvegarde existante : $backup_path"
    cp -p -- "$1" "$backup_path"
  fi
  chmod --reference="$1" "$output_tmp"
  mv -f -- "$output_tmp" "$1"
  trap - EXIT HUP INT TERM
}
