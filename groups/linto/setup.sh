#!/usr/bin/env bash
# linto-complete: opt --shell choices:zsh,bash,fish,ksh,sh Shell to configure (default: the invoking one)
# linto-complete: flag --man Also install the man page
set -euo pipefail

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto setup [--shell SHELL] [--man] [-h|--help]

Configure Linto for the current user's shell by adding the package and
user-generated command directories to PATH and installing shell completion.
The invoking shell is detected automatically; use --shell to select one
explicitly. Configuration lines are not duplicated. Use --man to also install
the Linto man page.

On NixOS, no files are changed; the matching NixOS options are printed instead.

Supported shells: zsh, bash, fish, ksh, sh. Completion is installed for zsh,
bash and fish; ksh and sh only get the PATH entries (ksh through ~/.kshrc,
loaded via ENV from ~/.profile; sh through ~/.profile).

Options:
  --shell SHELL  Shell to configure (default: the invoking one).
  --man          Also install the man page.
  -h, --help     Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

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
        ksh93|mksh) process_name=ksh ;;
      esac
      case "$process_name" in
        zsh|bash|fish|ksh|sh) printf '%s\n' "$process_name"; return ;;
      esac
    fi
    pid=$parent
  done

  local configured_shell=${SHELL:-}
  configured_shell=${configured_shell##*/}
  case "$configured_shell" in
    ksh93|mksh) printf '%s\n' ksh ;;
    zsh|bash|fish|ksh|sh) printf '%s\n' "$configured_shell" ;;
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
      [[ $# -ge 2 ]] || die_usage "option %s needs an argument" "$1"
      shell_name=$2
      shift 2
      ;;
    --shell=*) shell_name=${1#*=}; shift ;;
    --) shift; [[ $# -eq 0 ]] || die_usage "unexpected argument: %s" "$1" ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *) die_usage "unexpected argument: %s" "$1" ;;
  esac
done

is_nixos() {
  [[ -e /etc/NIXOS ]] || grep -qx 'ID=nixos' /etc/os-release 2>/dev/null
}

if is_nixos; then
  _ "$(cat <<'EOF'
This is NixOS: PATH and shell completion are managed declaratively, so no shell
files were changed. Add Linto to your NixOS configuration instead:

  imports = [ inputs.linto.nixosModules.default ];
  programs.linto = {
    enable = true;
    # Optional system-wide settings, written to /etc/linto/linto.yml:
    # settings.groups.quarto.configdata.extension = "chris2fr/quarto";
  };

The module installs the linto command, Bash/Fish/Zsh completions, and the
runtime dependencies. Per-user settings stay in ~/.config/linto/config.yml.
EOF
)"
  echo
  exit 0
fi

case "$shell_name" in
  ksh93|mksh) shell_name=ksh ;;
esac
case "$shell_name" in
  zsh|bash|fish|ksh|sh) ;;
  *) die "unsupported shell '%s' (supported: zsh, bash, fish, ksh, sh)" "$shell_name" ;;
esac

repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
bin_dir="$repo_dir/bin"
completion_dir="$repo_dir/completions"
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
[[ -x "$bin_dir/linto" ]] || die "dispatcher not found or not executable: %s" "$bin_dir/linto"

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
  ksh)
    config_file="$HOME/.kshrc"
    completion_line=''
    init_line=''
    path_line="export PATH=\"$bin_dir:$user_bin_dir:\$PATH\""
    ;;
  sh)
    config_file="$HOME/.profile"
    completion_line=''
    init_line=''
    path_line="export PATH=\"$bin_dir:$user_bin_dir:\$PATH\""
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
    die "could not update Zsh completion order in %s" "$config_file"
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

# ksh only reads ~/.kshrc when ENV points at it, which login shells set in ~/.profile.
if [[ "$shell_name" == ksh ]]; then
  profile="$HOME/.profile"
  env_line='export ENV="${ENV:-$HOME/.kshrc}"'
  [[ -f "$profile" ]] || : > "$profile"
  grep -Fqx -- "$env_line" "$profile" || printf '\n%s\n' "$env_line" >> "$profile"
fi

if [[ "$install_man" == true ]]; then
  "$repo_dir/groups/linto/addman.sh"
fi

printf "$(_ 'Configured Linto for %s in %s')\n" "$shell_name" "$config_file"
case "$shell_name" in
  ksh|sh) printf "$(_ 'Reload with: . %q')\n" "$config_file" ;;
  *) printf "$(_ 'Reload with: source %q')\n" "$config_file" ;;
esac
if [[ "$install_man" == false ]]; then
  printf '%s\n' "$(_ 'Run linto linto addman or repeat with --man to install the man page.')"
fi
