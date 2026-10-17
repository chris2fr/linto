#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: addman.sh [-h|--help]

Install the linto man page for the current user by creating a symbolic link in
~/.local/share/man/man1. Prints the MANPATH setup line if needed.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; exit 2 ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
source_man=$(CDPATH= cd -- "$script_dir/../man" && pwd -P)/linto.1
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
man_dir="$data_home/man/man1"
link_path="$man_dir/linto.1"

if [ ! -f "$source_man" ]; then
  printf 'error: man page not found: %s\n' "$source_man" >&2
  exit 1
fi

mkdir -p "$man_dir"
if [ -L "$link_path" ]; then
  existing_target=$(readlink -f -- "$link_path" || true)
  if [ "$existing_target" = "$source_man" ]; then
    printf 'Man page already linked: %s\n' "$link_path"
  else
    printf 'error: refusing to replace existing symbolic link: %s\n' "$link_path" >&2
    exit 1
  fi
elif [ -e "$link_path" ]; then
  printf 'error: refusing to replace existing file: %s\n' "$link_path" >&2
  exit 1
else
  ln -s "$source_man" "$link_path"
  printf 'Linked %s -> %s\n' "$link_path" "$source_man"
fi

printf '\nIf `man linto` is not found, add this to your shell configuration:\n'
printf 'export MANPATH="%s:${MANPATH:-}"\n' "$data_home/man"
