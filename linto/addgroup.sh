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

# Record the group as active; refresh.sh creates its wrappers and completions.
groups_file="$bin_dir/.linto-groups"
touch "$groups_file"
if ! grep -Fxq -- "$name" "$groups_file"; then
  printf '%s\n' "$name" >> "$groups_file"
  LC_ALL=C sort -u "$groups_file" -o "$groups_file"
fi

# Validate that exposed command names can be represented by the wrapper naming convention.
wrappers=("$bin_dir/linto-$name")
for script in "${executables[@]}"; do
  command_name=${script##*/}
  command_name=${command_name%.sh}
  case "$name/$command_name" in
    linto/addgroup|linto/rmgroup|linto/refresh) continue ;;
  esac
  [[ "$command_name" != *-* ]] || continue
done

printf 'Registered group %s with %d executable script(s).\n' "$name" "${#executables[@]}"
"$script_dir/linto/refresh.sh"
printf 'Available via: linto %s\n' "$name"
