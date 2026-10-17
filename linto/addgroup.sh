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

# Validate every destination before creating any wrappers.
wrappers=("$bin_dir/linto-$name")
for script in "${executables[@]}"; do
  command_name=${script##*/}
  command_name=${command_name%.sh}
  [[ "$command_name" != *-* ]] || fail "script name cannot be represented by the wrapper convention: ${script##*/}"
  wrappers+=("$bin_dir/linto-$name-$command_name")
done
for wrapper in "${wrappers[@]}"; do
  [[ ! -e "$wrapper" && ! -L "$wrapper" ]] || fail "refusing to overwrite existing path: $wrapper"
done

write_wrapper() {
  local destination=$1 group=$2 command=${3-}
  {
    printf '%s\n' '#!/bin/sh'
    printf '%s\n' 'bin_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)'
    if [[ -n "$command" ]]; then
      printf 'exec "$bin_dir/linto" %q %q "$@"\n' "$group" "$command"
    else
      printf 'exec "$bin_dir/linto" %q "$@"\n' "$group"
    fi
  } > "$destination"
  chmod 755 "$destination"
}

write_wrapper "${wrappers[0]}" "$name"
for index in "${!executables[@]}"; do
  script=${executables[$index]}
  command_name=${script##*/}
  command_name=${command_name%.sh}
  write_wrapper "${wrappers[$((index + 1))]}" "$name" "$command_name"
done

printf 'Registered group %s with %d executable script(s).\n' "$name" "${#executables[@]}"
printf 'Available via: linto %s\n' "$name"
