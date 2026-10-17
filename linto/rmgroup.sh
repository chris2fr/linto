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

# Only delete wrappers whose contents match the exact wrapper format produced
# by addgroup.sh. This leaves manually created bin commands untouched.
wrappers=("$bin_dir/linto-$name" "$bin_dir"/linto-"$name"-*)
deleted=0
for wrapper in "${wrappers[@]}"; do
  [[ -f "$wrapper" && ! -L "$wrapper" ]] || continue
  if ! grep -Fqx '#!/bin/sh' "$wrapper" ||
     ! grep -Fqx 'bin_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)' "$wrapper" ||
     ! grep -Fq "exec \"\$bin_dir/linto\" $name" "$wrapper"; then
    fail "refusing to remove wrapper not generated for group '$name': $wrapper"
  fi
done

for wrapper in "${wrappers[@]}"; do
  [[ -f "$wrapper" && ! -L "$wrapper" ]] || continue
  rm -- "$wrapper"
  deleted=$((deleted + 1))
done

# A group exclusion keeps the directory available on disk while excluding it
# from group discovery and group-qualified dispatch.
disabled_dir="$bin_dir/.disabled-groups"
mkdir -p -- "$disabled_dir"
: > "$disabled_dir/$name"

printf 'Unregistered group %s; removed %d wrapper(s).\n' "$name" "$deleted"
printf 'Directory left untouched: %s\n' "$group_dir"
