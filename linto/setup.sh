#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup.sh [--shell SHELL] [--man] [-h|--help]

Configure Linto for the current user's shell by adding the package and
user-generated command directories to PATH and installing shell completion.
The invoking shell is detected automatically; use --shell to select one
explicitly. Configuration lines are not duplicated. Use --man to also install
the Linto man page.

Supported shells: zsh, bash, fish
EOF
}

fail() {
  printf 'linto setup: %s\n' "$*" >&2
  exit 1
}

detect_current_shell() {
  local pid=$PPID parent line process_name argument is_script
  local -a argv
  while [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )); do
    process_name=
    IFS= read -r process_name < "/proc/$pid/comm" 2>/dev/null || break
    process_name=${process_name##*/}
    process_name=${process_name#-}

    parent=
    while IFS= read -r line; do
      if [[ "$line" == PPid:* ]]; then
        parent=${line#PPid:}
        parent=${parent//[[:space:]]/}
        break
      fi
    done < "/proc/$pid/status" 2>/dev/null || break

    is_script=false
    argv=()
    while IFS= read -r -d '' argument; do
      argv+=("$argument")
    done < "/proc/$pid/cmdline" 2>/dev/null || true
    for argument in "${argv[@]:1}"; do
      [[ "$argument" != -* && -f "$argument" ]] || continue
      if IFS= read -r line < "$argument" && [[ "$line" == '#!'* ]]; then
        is_script=true
        break
      fi
    done
    if [[ "$is_script" == false ]]; then
      case "$process_name" in
        zsh|bash|fish) printf '%s\n' "$process_name"; return ;;
      esac
    fi
    pid=$parent
  done

  local configured_shell=${SHELL:-}
  configured_shell=${configured_shell##*/}
  case "$configured_shell" in
    zsh|bash|fish) printf '%s\n' "$configured_shell" ;;
    *) printf '%s\n' bash ;;
  esac
}

shell_name=$(detect_current_shell)
install_man=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --man) install_man=true; shift ;;
    --shell)
      [[ $# -ge 2 ]] || fail '--shell requires zsh, bash, or fish'
      shell_name=$2
      shift 2
      ;;
    --shell=*) shell_name=${1#*=}; shift ;;
    --) shift; [[ $# -eq 0 ]] || { usage >&2; exit 2; } ;;
    *) usage >&2; exit 2 ;;
  esac
done

case "$shell_name" in
  zsh|bash|fish) ;;
  *) fail "unsupported shell '$shell_name' (supported: zsh, bash, fish)" ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
bin_dir="$script_dir/bin"
completion_dir="$script_dir/completions"
case "${XDG_DATA_HOME:-}" in
  /*) data_home=$XDG_DATA_HOME ;;
  *) data_home=$HOME/.local/share ;;
esac
case "${XDG_CONFIG_HOME:-}" in
  /*) config_home=$XDG_CONFIG_HOME ;;
  *) config_home=$HOME/.config ;;
esac
user_data_dir="$data_home/linto"
user_bin_dir="$user_data_dir/bin"
fish_completion="$user_data_dir/completions/linto.fish"
[[ -x "$bin_dir/linto" ]] || fail "dispatcher not found or not executable: $bin_dir/linto"

case "$shell_name" in
  zsh)
    config_file="${ZDOTDIR:-$HOME}/.zshrc"
    completion_line="fpath=(\"$completion_dir\" \$fpath)"
    init_line='autoload -Uz compinit && compinit'
    path_line="export PATH=\"$bin_dir:$user_bin_dir:\$PATH\""
    ;;
  bash)
    config_file="$HOME/.bashrc"
    completion_line="source \"$completion_dir/linto.bash\""
    init_line=''
    path_line="export PATH=\"$bin_dir:$user_bin_dir:\$PATH\""
    ;;
  fish)
    config_file="$config_home/fish/config.fish"
    [[ -f "$fish_completion" ]] || fish_completion="$completion_dir/linto.fish"
    completion_line="source \"$fish_completion\""
    init_line=''
    path_line="fish_add_path \"$bin_dir\" \"$user_bin_dir\""
    ;;
esac

mkdir -p -- "$(dirname -- "$config_file")"
[[ -f "$config_file" ]] || : > "$config_file"

append_once() {
  local line=$1
  [[ -n "$line" ]] || return 0
  grep -Fqx -- "$line" "$config_file" && return 0
  printf '\n%s\n' "$line" >> "$config_file"
}

ensure_zsh_completion_order() {
  local temporary
  temporary=$(mktemp "${config_file}.linto.XXXXXX")
  if ! awk -v line="$completion_line" '
    $0 == line { next }
    !inserted && /(^|[;&[:space:]])(autoload[[:space:]]+-Uz[[:space:]]+compinit|compinit)([;&[:space:]]|$)/ {
      print line
      inserted = 1
    }
    { print }
    END { if (!inserted) print line }
  ' "$config_file" > "$temporary"; then
    rm -f -- "$temporary"
    fail "could not update Zsh completion order in $config_file"
  fi
  chmod --reference="$config_file" "$temporary" 2>/dev/null || true
  mv -- "$temporary" "$config_file"

  if ! grep -Eq '(^|[;&[:space:]])(autoload[[:space:]]+-Uz[[:space:]]+compinit|compinit)([;&[:space:]]|$)' "$config_file"; then
    append_once "$init_line"
  fi
}

# Zsh must have the completion directory on fpath before compinit runs.
if [[ "$shell_name" == zsh ]]; then
  ensure_zsh_completion_order
else
  append_once "$completion_line"
fi
append_once "$path_line"

if [[ "$install_man" == true ]]; then
  "$script_dir/linto/addman.sh"
fi

printf 'Configured Linto for %s in %s\n' "$shell_name" "$config_file"
printf 'Reload with: source %q\n' "$config_file"
if [[ "$install_man" == false ]]; then
  printf 'Run linto linto addman or repeat with --man to install the man page.\n'
fi
