#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: addgroup.sh [-h|--help] DIRECTORY

Register a top-level Linto directory as a command group. DIRECTORY may name an
existing eligible group, or a directory outside the Linto root to be copied
into it. Executable *.sh files in the group are exposed through generated
bin/linto-GROUP-COMMAND wrappers; bin/linto-GROUP lists the group's commands.
Existing wrappers are never overwritten.
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
bin_dir="$script_dir/bin"

name=${source_dir##*/}
case "$name" in
  ''|.*|bin|completions|man|old|tests|lib|*[!a-zA-Z0-9_-]*)
    fail "invalid or reserved group name: $name"
    ;;
esac

group_dir="$script_dir/$name"
if [[ "$source_dir" != "$group_dir" ]]; then
  [[ ! -e "$group_dir" ]] || fail "group directory already exists: $group_dir"
  cp -R -- "$source_dir" "$group_dir"
  printf 'Copied group directory: %s\n' "$group_dir"
fi

shopt -s nullglob
scripts=("$group_dir"/*.sh)
shopt -u nullglob
executables=()
for script in "${scripts[@]}"; do
  [[ -f "$script" && -x "$script" ]] && executables+=("$script")
done

# Add the group with default settings, or re-enable its existing config.
config_file="$script_dir/config.yml"
[[ -f "$config_file" ]] || fail "configuration file not found: $config_file"
python3 "$script_dir/lib/config.py" "$config_file" add "$name" || fail "could not update group configuration"


printf 'Registered group %s with %d executable script(s).\n' "$name" "${#executables[@]}"
"$script_dir/linto/refresh.sh"
printf 'Available via: linto %s\n' "$name"
