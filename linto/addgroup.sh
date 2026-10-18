#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: addgroup.sh [-h|--help] DIRECTORY

Register a command group. DIRECTORY may name an existing installed/user group
or an outside directory, which is copied into the user's Linto data directory.
Executable *.sh files are exposed through generated user-level wrappers.
EOF
}

fail() {
  printf 'addgroup: %s\n' "$*" >&2
  exit 1
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  --) shift ;;
esac

[[ $# -eq 1 ]] || { usage >&2; exit 2; }
source_dir=$1
[[ -d "$source_dir" ]] || fail "not a directory: $source_dir"
source_dir=$(CDPATH= cd -- "$source_dir" && pwd -P)
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
case "${XDG_DATA_HOME:-}" in
  /*) data_home=$XDG_DATA_HOME ;;
  *) data_home=$HOME/.local/share ;;
esac
user_groups="$data_home/linto/groups"

name=${source_dir##*/}
case "$name" in
  ''|.*|bin|completions|man|old|tests|lib|*[!a-zA-Z0-9_-]*)
    fail "invalid or reserved group name: $name"
    ;;
esac

package_group="$script_dir/$name"
user_group="$user_groups/$name"
if [[ "$source_dir" == "$package_group" ]]; then
  group_dir=$package_group
elif [[ "$source_dir" == "$user_group" ]]; then
  group_dir=$user_group
else
  [[ ! -e "$package_group" && ! -e "$user_group" ]] || fail "group directory already exists: $name"
  mkdir -p -- "$user_groups"
  cp -R -- "$source_dir" "$user_group"
  group_dir=$user_group
  printf 'Copied group directory: %s\n' "$group_dir"
fi

shopt -s nullglob
scripts=("$group_dir"/*.sh)
shopt -u nullglob
executables=()
for script in "${scripts[@]}"; do
  [[ -f "$script" && -x "$script" ]] && executables+=("$script")
done

# Register or re-enable the group in the writable user configuration.
config_file="$script_dir/config.yml"
[[ -f "$config_file" ]] || fail "installation configuration file not found: $config_file"
python3 "$script_dir/lib/config.py" "$config_file" add "$name" || fail "could not update user group configuration"


printf 'Registered group %s with %d executable script(s).\n' "$name" "${#executables[@]}"
"$script_dir/linto/refresh.sh"
printf 'Available via: linto %s\n' "$name"
