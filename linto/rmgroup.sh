#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: rmgroup.sh [-h|--help] GROUP

Unregister a Linto command group without changing or deleting its directory.
Removes the generated bin/linto-GROUP and bin/linto-GROUP-COMMAND wrappers and
marks the group as disabled so the dispatcher, help, and completions ignore it.
The group directory and all of its contents are left untouched.
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

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
bin_dir="$script_dir/bin"
group_dir="$script_dir/$name"
[[ -d "$group_dir" ]] || fail "group directory not found: $group_dir"

config_file="$script_dir/config.yml"
[[ -f "$config_file" ]] || fail "configuration file not found: $config_file"
grep -Eq "^[[:space:]]*-[[:space:]]*${name}[[:space:]]*$" "$config_file" || fail "group is not active: $name"
tmp_config=$(mktemp "$script_dir/.config.yml.XXXXXX")
trap 'rm -f -- "$tmp_config"' EXIT
sed "/^[[:space:]]*-[[:space:]]*${name}[[:space:]]*$/d" "$config_file" > "$tmp_config"
mv -- "$tmp_config" "$config_file"

"$script_dir/linto/refresh.sh"
printf 'Unregistered group %s.\n' "$name"
printf 'Directory left untouched: %s\n' "$group_dir"
