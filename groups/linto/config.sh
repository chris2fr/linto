#!/bin/sh
# linto-complete: opt --group value Show a group's configdata
# linto-complete: opt --command value Include command-level configdata
# linto-complete: opt --editor value Editor program to use with --edit
# linto-complete: flag --edit Open config.yml in an editor
# linto-complete: flag --effective Print the full merged configuration
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto config [-h|--help] [--group GROUP [--command COMMAND] | --effective]
                          [--edit] [--editor PROGRAM]

Without options, print the user config directory and file. --group shows the
selected group's effective configdata; --command includes command-level
configdata. --effective prints the full configuration with defaults merged.
With --edit, open config.yml with `linto launch zed`; --editor selects another
executable instead. Editing creates an empty user override file if needed.

Options:
  -g, --group GROUP     Show the effective configdata of GROUP.
  -c, --command NAME    With --group, include command-level configdata.
      --effective       Print the full merged configuration.
  -e, --edit            Open config.yml in an editor.
      --editor PROGRAM  Editor program to use (implies --edit).
  -h, --help            Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/../../lib/common.sh"

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
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      group=$2
      shift 2
      ;;
    --group=*)
      group=${1#*=}
      [ -n "${1#*=}" ] || die_usage "option %s needs an argument" "--group"
      shift
      ;;
    -c|--command)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      command=$2
      shift 2
      ;;
    --command=*)
      command=${1#*=}
      [ -n "${1#*=}" ] || die_usage "option %s needs an argument" "--command"
      shift
      ;;
    --editor)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      editor=$2
      edit=true
      shift 2
      ;;
    --editor=*)
      editor=${1#*=}
      [ -n "${1#*=}" ] || die_usage "option %s needs an argument" "--editor"
      edit=true
      shift
      ;;
    --)
      shift
      [ "$#" -eq 0 ] || die_usage "unexpected argument: %s" "$1"
      ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *) die_usage "unexpected argument: %s" "$1" ;;
  esac
done

case "${XDG_CONFIG_HOME:-}" in
  /*) config_home=$XDG_CONFIG_HOME ;;
  *) config_home=$HOME/.config ;;
esac
config_dir="$config_home/linto"
config_file="$config_dir/config.yml"
repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)

if [ "$edit" = true ] && { [ "$show_effective" = true ] || [ -n "$group" ] || [ -n "$command" ]; }; then
  die_usage "--edit cannot be combined with --effective, --group, or --command"
fi
if [ "$show_effective" = true ] && { [ -n "$group" ] || [ -n "$command" ]; }; then
  die_usage "--effective cannot be combined with --group or --command"
fi
if [ -n "$command" ] && [ -z "$group" ]; then
  die_usage "--command requires --group"
fi

if [ "$show_effective" = true ]; then
  exec python3 "$repo_dir/lib/config.py" "$repo_dir/config.yml" effective
fi
if [ -n "$group" ]; then
  if [ -n "$command" ]; then
    exec python3 "$repo_dir/lib/config.py" "$repo_dir/config.yml" configdata "$group" "$command"
  fi
  exec python3 "$repo_dir/lib/config.py" "$repo_dir/config.yml" configdata "$group"
fi
if [ "$edit" != true ]; then
  printf "$(_ 'User config directory: %s')\n$(_ 'User config file: %s')\n" "$config_dir" "$config_file"
  exit 0
fi

mkdir -p -- "$config_dir"
if [ ! -e "$config_file" ]; then
  : > "$config_file"
fi

if [ -n "$editor" ]; then
  command -v "$editor" >/dev/null 2>&1 || {
    die "editor not found: %s" "$editor"
  }
  exec "$editor" "$config_file"
fi

exec "$repo_dir/bin/linto" launch zed "$config_file"
