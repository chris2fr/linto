#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: config.sh [-h|--help] [--edit] [--editor PROGRAM]

Print Linto's user configuration directory and config file. With --edit, open
config.yml with `linto launch zed`; --editor selects another executable instead.
If the user config does not exist, it is created as an empty override file.
EOF
}

edit=false
editor=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -e|--edit)
      edit=true
      shift
      ;;
    --editor)
      [ "$#" -ge 2 ] || { echo 'config: --editor requires a program' >&2; exit 2; }
      editor=$2
      edit=true
      shift 2
      ;;
    --editor=*)
      editor=${1#*=}
      [ -n "$editor" ] || { echo 'config: --editor requires a program' >&2; exit 2; }
      edit=true
      shift
      ;;
    --)
      shift
      [ "$#" -eq 0 ] || { usage >&2; exit 2; }
      ;;
    *)
      printf 'config: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "${XDG_CONFIG_HOME:-}" in
  /*) config_home=$XDG_CONFIG_HOME ;;
  *) config_home=$HOME/.config ;;
esac
config_dir="$config_home/linto"
config_file="$config_dir/config.yml"

if [ "$edit" != true ]; then
  printf 'User config directory: %s\nUser config file: %s\n' "$config_dir" "$config_file"
  exit 0
fi

mkdir -p -- "$config_dir"
if [ ! -e "$config_file" ]; then
  : > "$config_file"
fi

if [ -n "$editor" ]; then
  command -v "$editor" >/dev/null 2>&1 || {
    printf 'config: editor not found: %s\n' "$editor" >&2
    exit 1
  }
  exec "$editor" "$config_file"
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
exec "$script_dir/bin/linto" launch zed "$config_file"
