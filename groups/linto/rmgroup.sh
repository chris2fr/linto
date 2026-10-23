#!/usr/bin/env bash
# linto-complete: arg 1 value
set -euo pipefail

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto rmgroup [-h|--help] GROUP

Disable a command group in the user's Linto configuration without deleting its
installed or user data directory. Generated wrappers and completions are
reconciled by build.

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

[[ $# -eq 1 ]] || die_usage "exactly one %s is expected" "$(_ "group")"
name=$1
case "$name" in
  ''|.*|bin|completions|man|tests|lib|*[!a-zA-Z0-9_-]*)
    die "invalid or reserved group name: %s" "$name"
    ;;
esac

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
case "${XDG_DATA_HOME:-}" in
  /*) data_home=$XDG_DATA_HOME ;;
  *) data_home=$HOME/.local/share ;;
esac
package_group="$repo_dir/groups/$name"
user_group="$data_home/linto/groups/$name"
[[ -d "$package_group" || -d "$user_group" ]] || die "group directory not found: %s" "$name"

config_file="$repo_dir/config.yml"
[[ -f "$config_file" ]] || die "installation configuration file not found: %s" "$config_file"
python3 "$repo_dir/lib/config.py" "$config_file" remove "$name" || die "could not update user group configuration"

"$repo_dir/groups/linto/build.sh"
printf "$(_ 'Unregistered group %s.')\n" "$name"
for group_path in "$package_group" "$user_group"; do
  [[ -d "$group_path" ]] && printf "$(_ 'Group files left untouched: %s')\n" "$group_path"
done
