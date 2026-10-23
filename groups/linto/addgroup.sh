#!/usr/bin/env bash
# linto-complete: arg 1 dir
set -euo pipefail

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto addgroup [-h|--help] DIRECTORY

Register a command group. DIRECTORY may name an existing installed/user group
or an outside directory, which is copied into the user's Linto data directory.
Executable *.sh files are exposed through generated user-level wrappers.

Options:
  -h, --help  Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  --) shift ;;
  -?*) die_usage "unknown option: %s" "$1" ;;
esac

[[ $# -eq 1 ]] || die_usage "exactly one %s is expected" "$(_ "directory")"
source_dir=$1
[[ -d "$source_dir" ]] || die "not a directory: %s" "$source_dir"
source_dir=$(CDPATH= cd -- "$source_dir" && pwd -P)
repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
case "${XDG_DATA_HOME:-}" in
  /*) data_home=$XDG_DATA_HOME ;;
  *) data_home=$HOME/.local/share ;;
esac
user_groups="$data_home/linto/groups"

name=${source_dir##*/}
case "$name" in
  ''|.*|bin|completions|man|tests|lib|*[!a-zA-Z0-9_-]*)
    die "invalid or reserved group name: %s" "$name"
    ;;
esac

package_group="$repo_dir/groups/$name"
user_group="$user_groups/$name"
if [[ "$source_dir" == "$package_group" ]]; then
  group_dir=$package_group
elif [[ "$source_dir" == "$user_group" ]]; then
  group_dir=$user_group
else
  [[ ! -e "$package_group" && ! -e "$user_group" ]] || die "group directory already exists: %s" "$name"
  mkdir -p -- "$user_groups"
  cp -R -- "$source_dir" "$user_group"
  group_dir=$user_group
  printf "$(_ 'Copied group directory: %s')\n" "$group_dir"
fi

shopt -s nullglob
scripts=("$group_dir"/*.sh)
shopt -u nullglob
executables=()
for script in "${scripts[@]}"; do
  [[ -f "$script" && -x "$script" ]] && executables+=("$script")
done

# Register or re-enable the group in the writable user configuration.
config_file="$repo_dir/config.yml"
[[ -f "$config_file" ]] || die "installation configuration file not found: %s" "$config_file"
python3 "$repo_dir/lib/config.py" "$config_file" add "$name" || die "could not update user group configuration"


printf "$(_ 'Registered group %s with %d executable script(s).')\n" "$name" "${#executables[@]}"
"$repo_dir/groups/linto/build.sh"
printf "$(_ 'Available via: linto %s')\n" "$name"
