#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: rmgroup.sh [-h|--help] GROUP

Disable a command group in the user's Linto configuration without deleting its
installed or user data directory. Generated wrappers and completions are
reconciled by refresh.
EOF
}

fail() {
  printf 'rmgroup: %s\n' "$*" >&2
  exit 1
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  --) shift ;;
esac

[[ $# -eq 1 ]] || { usage >&2; exit 2; }
name=$1
case "$name" in
  ''|.*|bin|completions|man|old|tests|lib|*[!a-zA-Z0-9_-]*)
    fail "invalid or reserved group name: $name"
    ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
case "${XDG_DATA_HOME:-}" in
  /*) data_home=$XDG_DATA_HOME ;;
  *) data_home=$HOME/.local/share ;;
esac
package_group="$script_dir/groups/$name"
user_group="$data_home/linto/groups/$name"
[[ -d "$package_group" || -d "$user_group" ]] || fail "group directory not found: $name"

config_file="$script_dir/config.yml"
[[ -f "$config_file" ]] || fail "installation configuration file not found: $config_file"
python3 "$script_dir/lib/config.py" "$config_file" remove "$name" || fail "could not update user group configuration"

"$script_dir/groups/linto/refresh.sh"
printf 'Unregistered group %s.\n' "$name"
for group_path in "$package_group" "$user_group"; do
  [[ -d "$group_path" ]] && printf 'Group files left untouched: %s\n' "$group_path"
done
