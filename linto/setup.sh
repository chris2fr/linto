#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup.sh [--shell SHELL] [--man] [-h|--help]

Configure Linto for the current user's shell by adding bin/ to PATH and
installing the matching command completion. The shell defaults to $SHELL.
Configuration files are backed up before modification and setup lines are not
duplicated. Use --man to also run linto-linto-addman.

Supported shells: zsh, bash
EOF
}

fail() {
  printf 'linto setup: %s\n' "$*" >&2
  exit 1
}

shell_name=${SHELL##*/}
install_man=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --man) install_man=true; shift ;;
    --shell)
      [[ $# -ge 2 ]] || fail '--shell requires zsh or bash'
      shell_name=$2
      shift 2
      ;;
    --shell=*) shell_name=${1#*=}; shift ;;
    --) shift; [[ $# -eq 0 ]] || { usage >&2; exit 2; } ;;
    *) usage >&2; exit 2 ;;
  esac
done

case "$shell_name" in
  zsh|bash) ;;
  *) fail "unsupported shell '$shell_name' (supported: zsh, bash)" ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
bin_dir="$script_dir/bin"
completion_dir="$script_dir/completions"
[[ -x "$bin_dir/linto" ]] || fail "dispatcher not found or not executable: $bin_dir/linto"

if [[ "$shell_name" == zsh ]]; then
  config_file="${ZDOTDIR:-$HOME}/.zshrc"
  completion_line="fpath=(\"$completion_dir\" \$fpath)"
  init_line='autoload -Uz compinit && compinit'
else
  config_file="$HOME/.bashrc"
  completion_line="source \"$completion_dir/linto.bash\""
  init_line=''
fi
path_line="export PATH=\"$bin_dir:\$PATH\""

mkdir -p -- "$(dirname -- "$config_file")"
[[ -f "$config_file" ]] || : > "$config_file"

append_once() {
  local line=$1
  [[ -n "$line" ]] || return 0
  grep -Fqx -- "$line" "$config_file" && return 0
  printf '\n%s\n' "$line" >> "$config_file"
}

# Ensure Zsh loads the Linto function from fpath before compinit. Avoid adding a
# second compinit when an existing initialization is already present.
if [[ "$shell_name" == zsh ]]; then
  if grep -Fqx -- "$completion_line" "$config_file"; then
    :
  else
    append_once "$completion_line"
  fi
  if ! grep -Eq '(^|[;&[:space:]])(autoload[[:space:]]+-Uz[[:space:]]+compinit|compinit)([;&[:space:]]|$)' "$config_file"; then
    append_once "$init_line"
  fi
else
  append_once "$completion_line"
fi
append_once "$path_line"

if [[ "$install_man" == true ]]; then
  "$bin_dir/linto-linto-addman"
fi

printf 'Configured Linto for %s in %s\n' "$shell_name" "$config_file"
printf 'Reload with: source %q\n' "$config_file"
if [[ "$install_man" == false ]]; then
  printf 'Run linto-linto-addman or repeat with --man to install the man page.\n'
fi
