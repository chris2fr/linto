#!/bin/sh
# linto-complete: opt --group value
# linto-complete: opt --command value
# linto-complete: opt --editor value
# linto-complete: flag --edit,--effective
set -eu

usage() {
  cat <<'EOF'
Usage: config.sh [-h|--help] [--group GROUP [--command COMMAND] | --effective]
                 [--edit] [--editor PROGRAM]

Without options, print the user config directory and file. --group shows the
selected group's effective configdata; --command includes command-level
configdata. --effective prints the full configuration with defaults merged.
With --edit, open config.yml with `linto launch zed`; --editor selects another
executable instead. Editing creates an empty user override file if needed.
EOF
}

edit=false
show_effective=false
group=
command=
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
    --effective|--show)
      show_effective=true
      shift
      ;;
    -g|--group)
      [ "$#" -ge 2 ] || { echo 'config: --group requires a name' >&2; exit 2; }
      group=$2
      shift 2
      ;;
    --group=*)
      group=${1#*=}
      [ -n "$group" ] || { echo 'config: --group requires a name' >&2; exit 2; }
      shift
      ;;
    -c|--command)
      [ "$#" -ge 2 ] || { echo 'config: --command requires a name' >&2; exit 2; }
      command=$2
      shift 2
      ;;
    --command=*)
      command=${1#*=}
      [ -n "$command" ] || { echo 'config: --command requires a name' >&2; exit 2; }
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
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)

if [ "$edit" = true ] && { [ "$show_effective" = true ] || [ -n "$group" ] || [ -n "$command" ]; }; then
  echo 'config: --edit cannot be combined with --effective, --group, or --command' >&2
  exit 2
fi
if [ "$show_effective" = true ] && { [ -n "$group" ] || [ -n "$command" ]; }; then
  echo 'config: --effective cannot be combined with --group or --command' >&2
  exit 2
fi
if [ -n "$command" ] && [ -z "$group" ]; then
  echo 'config: --command requires --group' >&2
  exit 2
fi

if [ "$show_effective" = true ]; then
  exec python3 "$script_dir/lib/config.py" "$script_dir/config.yml" effective
fi
if [ -n "$group" ]; then
  if [ -n "$command" ]; then
    exec python3 "$script_dir/lib/config.py" "$script_dir/config.yml" configdata "$group" "$command"
  fi
  exec python3 "$script_dir/lib/config.py" "$script_dir/config.yml" configdata "$group"
fi
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

exec "$script_dir/bin/linto" launch zed "$config_file"
