#!/bin/sh
# linto-complete: none
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto addman [-h|--help]

Generate and install the user's Linto man page in the XDG data directory.

Options:
  -h, --help  Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/../../lib/common.sh"

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  -?*) die_usage "unknown option: %s" "$1" ;;
  *) die_usage "unexpected argument: %s" "$1" ;;
esac

repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
case "${XDG_DATA_HOME:-}" in
  /*) data_home=$XDG_DATA_HOME ;;
  *) data_home=$HOME/.local/share ;;
esac
linto_data="$data_home/linto"
source_man="$linto_data/man/man1/linto.1"
man_dir="$data_home/man/man1"
link_path="$man_dir/linto.1"

"$repo_root/groups/linto/refresh.sh"
if [ ! -f "$source_man" ]; then
  die "generated man page not found: %s" "$source_man"
fi

mkdir -p "$man_dir"
if [ -L "$link_path" ]; then
  existing_target=$(readlink -f -- "$link_path" || true)
  if [ "$existing_target" = "$source_man" ]; then
    printf "$(_ 'Man page already linked: %s')\n" "$link_path"
  else
    die "refusing to replace existing symbolic link: %s" "$link_path"
  fi
elif [ -e "$link_path" ]; then
  die "refusing to replace existing file: %s" "$link_path"
else
  ln -s "$source_man" "$link_path"
  printf "$(_ 'Linked %s -> %s')\n" "$link_path" "$source_man"
fi

printf '\n%s\n' "$(_ 'If `man linto` is not found, add this to your shell configuration:')"
printf 'export MANPATH="%s:${MANPATH:-}"\n' "$data_home/man"
