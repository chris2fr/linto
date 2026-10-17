#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: refresh.sh [-h|--help]

Refresh generated group and command wrappers in bin/ and regenerate the Fish
completion definitions from bin/.linto-groups. Bash and Zsh completions query
the dispatcher dynamically. Only wrappers listed in the generated-wrapper
inventory are removed when they become obsolete.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; exit 2 ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
bin_dir="$script_dir/bin"
completion_dir="$script_dir/completions"
linto_bin="$bin_dir/linto"
groups_file="$bin_dir/.linto-groups"
wrapper_dir="$bin_dir/.generated-wrappers"
owned_file="$wrapper_dir/owned"

[[ -x "$linto_bin" ]] || { printf 'refresh: dispatcher is not executable: %s\n' "$linto_bin" >&2; exit 1; }
[[ -f "$groups_file" ]] || { printf 'refresh: group configuration not found: %s\n' "$groups_file" >&2; exit 1; }

mapfile -t groups < <("$linto_bin" --list-groups)
declare -a desired_names=()
declare -a desired_groups=()
declare -a desired_commands=()
declare -A desired_set=()

for group in "${groups[@]}"; do
  desired_names+=("linto-$group")
  desired_groups+=("$group")
  desired_commands+=("")
  desired_set["linto-$group"]=1

  mapfile -t commands < <("$linto_bin" --list-commands "$group")
  for command in "${commands[@]}"; do
    case "$group/$command" in
      linto/addgroup|linto/rmgroup|linto/refresh) continue ;;
    esac
    desired_names+=("linto-$group-$command")
    desired_groups+=("$group")
    desired_commands+=("$command")
    desired_set["linto-$group-$command"]=1
  done
done

mkdir -p -- "$wrapper_dir"
: > "$wrapper_dir/current"
for name in "${desired_names[@]}"; do
  printf '%s\n' "$name" >> "$wrapper_dir/current"
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

# Verify desired destinations. A pre-existing stub with the canonical format
# may be adopted; any other file, directory, or symlink is preserved and causes
# an error rather than being overwritten.
for index in "${!desired_names[@]}"; do
  name=${desired_names[$index]}
  destination="$bin_dir/$name"
  [[ -e "$destination" || -L "$destination" ]] || continue
  [[ -f "$destination" && ! -L "$destination" ]] || {
    printf 'refresh: refusing to replace non-file path: %s\n' "$destination" >&2
    exit 1
  }
  if [[ -n "${desired_commands[$index]}" ]]; then
    expected_line="exec \"\$bin_dir/linto\" ${desired_groups[$index]} ${desired_commands[$index]} \"\$@\""
  else
    expected_line="exec \"\$bin_dir/linto\" ${desired_groups[$index]} \"\$@\""
  fi
  if ! grep -Fqx '#!/bin/sh' "$destination" ||
     ! grep -Fqx 'bin_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)' "$destination" ||
     ! grep -Fqx "$expected_line" "$destination"; then
    printf 'refresh: refusing to replace unrecognized path: %s\n' "$destination" >&2
    exit 1
  fi
done

# Remove only obsolete paths that this refresh script previously recorded.
if [[ -f "$owned_file" ]]; then
  while IFS= read -r old_name; do
    [[ -n "$old_name" ]] || continue
    [[ -n "${desired_set[$old_name]+yes}" ]] || rm -f -- "$bin_dir/$old_name"
  done < "$owned_file"
fi

for index in "${!desired_names[@]}"; do
  name=${desired_names[$index]}
  destination="$bin_dir/$name"
  if [[ -e "$destination" ]]; then
    # Already validated above; normalize it to the current canonical form.
    write_wrapper "$destination" "${desired_groups[$index]}" "${desired_commands[$index]}"
  else
    write_wrapper "$destination" "${desired_groups[$index]}" "${desired_commands[$index]}"
  fi
done

mv -- "$wrapper_dir/current" "$owned_file"

cat > "$completion_dir/linto.fish" <<'FISH_HEADER'
set -l linto_bin (realpath (dirname (status filename))/../bin/linto)

complete -c linto -f -n '__fish_use_subcommand' -a 'help completion'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --list-groups 2>/dev/null)'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --list-groups 2>/dev/null | string replace -r "^(.*)$" "linto-$1")'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --help 2>/dev/null | string match -r "^  [[:alnum:]_-]+" | string trim)'
complete -c linto -f -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'
FISH_HEADER

for group in "${groups[@]}"; do
  cat >> "$completion_dir/linto.fish" <<EOF

complete -c linto -f -n '__fish_seen_subcommand_from $group linto-$group' -a '(\$linto_bin --list-commands $group 2>/dev/null)'
complete -c linto -f -n '__fish_use_subcommand' -a '(\$linto_bin --list-commands $group 2>/dev/null | string replace -r \'^(.*)\$\' \'linto-$group-\$1\')'
EOF
done

cat >> "$completion_dir/linto.fish" <<'FISH_FOOTER'

complete -c linto -f -n '__fish_seen_subcommand_from help' -a '($linto_bin --list-groups 2>/dev/null)'
complete -c linto -f -n '__fish_seen_subcommand_from help' -a '($linto_bin --help 2>/dev/null | string match -r "^  [[:alnum:]_-]+" | string trim)'
complete -c linto -l help -s h -d 'Show help'
FISH_FOOTER

printf 'Refreshed wrappers for %d group(s) and Fish completion.\n' "${#groups[@]}"
