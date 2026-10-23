#!/usr/bin/env bash
# linto-complete: flag --user Install for the current user
# linto-complete: flag --system Install for all users
# linto-complete: opt --shell choices:all,fish,bash,ksh,sh,zsh Shell to configure with --user (default: all)
# linto-complete: opt --prefix dir Installation prefix with --system (default: /usr/local)
# linto-complete: flag --no-man Do not install the man page
# linto-complete: flag --venv Also create the Python environment (linto linto venv)
set -euo pipefail

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto install [--user | --system] [--shell SHELL]... [--prefix DIR]
                           [--no-man] [--venv] [-h|--help]

Install Linto, for the current user (--user) or for all users (--system). When
neither is given, ask which.

--user runs in place from this checkout: it builds the command wrappers,
completions and man pages (linto linto build), then adds the checkout and
user-generated command directories to PATH and installs shell completion for
each selected shell. Configuration lines are not duplicated.

--system copies Linto to PREFIX/lib/linto, builds its wrappers into
PREFIX/share/linto, links the commands into PREFIX/bin, and installs the
completions and man pages under PREFIX/share. It needs write access to PREFIX
(normally root).

On NixOS, no files are changed; the matching NixOS options are printed instead.

Shells: fish, bash, ksh, sh, zsh (default: all of them). Completion is installed
for zsh, bash and fish; ksh and sh only get the PATH entries (ksh through
~/.kshrc, loaded via ENV from ~/.profile; sh through ~/.profile).

Options:
  --user         Install for the current user.
  --system       Install for all users.
  --shell SHELL  Shell to configure with --user: fish, bash, ksh, sh, zsh or all;
                 repeat it or separate shells with commas (default: all).
  --prefix DIR   Installation prefix with --system (default: /usr/local).
  --no-man       Do not install the man page.
  --venv         Also create the Python environment (linto linto venv).
  -h, --help     Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

ALL_SHELLS=(fish bash ksh sh zsh)

mode=
shells=()
prefix=
install_man=true
make_venv=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --user) mode=user; shift ;;
    --system) mode=system; shift ;;
    --no-man) install_man=false; shift ;;
    --man) install_man=true; shift ;;
    --venv) make_venv=true; shift ;;
    --shell)
      [[ $# -ge 2 ]] || die_usage "option %s needs an argument" "$1"
      shells+=("$2")
      shift 2
      ;;
    --shell=*) shells+=("${1#*=}"); shift ;;
    --prefix)
      [[ $# -ge 2 ]] || die_usage "option %s needs an argument" "$1"
      prefix=$2
      shift 2
      ;;
    --prefix=*) prefix=${1#*=}; shift ;;
    --) shift; [[ $# -eq 0 ]] || die_usage "unexpected argument: %s" "$1" ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *) die_usage "unexpected argument: %s" "$1" ;;
  esac
done

# --- mode -------------------------------------------------------------------
if [[ -z "$mode" ]]; then
  if [[ -t 0 && -t 1 ]]; then
    printf '%s ' "$(_ 'Install Linto for the current user or for all users (system)? [user/system]')"
    read -r answer || answer=
    case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
      ''|u|user|utilisateur) mode=user ;;
      s|system|systeme|système) mode=system ;;
      *) die_usage "unknown answer: %s" "$answer" ;;
    esac
  else
    die_usage "choose --user or --system"
  fi
fi
if [[ "$mode" == user && -n "$prefix" ]]; then
  die_usage "%s only applies with %s" "--prefix" "--system"
fi
if [[ "$mode" == system && ${#shells[@]} -gt 0 ]]; then
  die_usage "%s only applies with %s" "--shell" "--user"
fi

# --- shells -----------------------------------------------------------------
selected=()
if [[ "$mode" == user ]]; then
  [[ ${#shells[@]} -gt 0 ]] || shells=(all)
  for entry in "${shells[@]}"; do
    IFS=, read -r -a parts <<<"$entry"
    for name in "${parts[@]}"; do
      case "$name" in
        all) selected+=("${ALL_SHELLS[@]}") ;;
        ksh93|mksh) selected+=(ksh) ;;
        zsh|bash|fish|ksh|sh) selected+=("$name") ;;
        *) die "unsupported shell '%s' (supported: zsh, bash, fish, ksh, sh)" "$name" ;;
      esac
    done
  done
  # Remove duplicates, keeping the first occurrence.
  mapfile -t selected < <(printf '%s\n' "${selected[@]}" | awk '!seen[$0]++')
fi

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

repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
[[ -x "$repo_dir/bin/linto" ]] || die "dispatcher not found or not executable: %s" "$repo_dir/bin/linto"

# ============================================================================
# --system
# ============================================================================
install_system() {
  local prefix=${prefix:-/usr/local}
  local lib_dir="$prefix/lib/linto" share_dir="$prefix/share" bin_dir="$prefix/bin"
  local marker="$lib_dir/.linto-install" entry name target

  case "$prefix" in /*) ;; *) die "the prefix must be an absolute path: %s" "$prefix" ;; esac
  if [[ -e "$lib_dir" && ! -f "$marker" ]]; then
    die "refusing to replace %s: not a Linto installation" "$lib_dir"
  fi
  mkdir -p -- "$bin_dir" "$prefix/lib" 2>/dev/null && [[ -w "$bin_dir" && -w "$prefix/lib" ]] ||
    die "cannot write to %s (run as root, or choose another --prefix)" "$prefix"

  printf "$(_ 'Installing Linto in %s')\n" "$lib_dir"
  rm -rf -- "$lib_dir"
  mkdir -p -- "$lib_dir"
  (cd "$repo_dir" && tar --exclude=./.git --exclude=./.venv --exclude=./tests \
      --exclude=__pycache__ --exclude='*.pyc' -cf - .) | (cd "$lib_dir" && tar -xf -)
  printf '%s\n' "$(python3 "$lib_dir/lib/config.py" "$lib_dir/config.yml" version 2>/dev/null || echo unknown)" > "$marker"

  # Build the wrappers, completions and man pages for the whole system, ignoring
  # the configuration of whoever runs the installation.
  env HOME=/var/empty XDG_CONFIG_HOME=/var/empty XDG_DATA_HOME="$share_dir" \
    "$lib_dir/groups/linto/build.sh" >/dev/null

  # Commands: a launcher for the dispatcher (it must run from its own tree), and
  # links to the generated wrappers, which already hold absolute paths.
  printf '#!/bin/sh\nexec %q "$@"\n' "$lib_dir/bin/linto" > "$bin_dir/linto"
  chmod 0755 "$bin_dir/linto"
  for entry in "$share_dir/linto/bin"/*; do
    [[ -f "$entry" ]] || continue
    ln -sfn -- "$entry" "$bin_dir/${entry##*/}"
  done
  for entry in "$bin_dir"/linto-*; do                # wrappers of groups that no longer exist
    [[ -L "$entry" && ! -e "$entry" ]] || continue
    target=$(readlink -- "$entry")
    [[ "$target" == "$share_dir/linto/bin/"* ]] && rm -f -- "$entry"
  done

  # Completions.
  mkdir -p -- "$share_dir/bash-completion/completions" "$share_dir/zsh/site-functions" \
    "$share_dir/fish/vendor_completions.d"
  printf 'source %q\n' "$lib_dir/completions/linto.bash" > "$share_dir/bash-completion/completions/linto"
  ln -sfn -- "$lib_dir/completions/_linto" "$share_dir/zsh/site-functions/_linto"
  printf 'source %q\n' "$share_dir/linto/completions/linto.fish" > "$share_dir/fish/vendor_completions.d/linto.fish"

  # Man pages.
  if [[ "$install_man" == true ]]; then
    mkdir -p -- "$share_dir/man/man1"
    for entry in "$share_dir/linto/man/man1"/linto*.1; do
      [[ -f "$entry" ]] && install -m 0644 -- "$entry" "$share_dir/man/man1/${entry##*/}"
    done
  fi

  if [[ "$make_venv" == true ]]; then
    "$lib_dir/groups/linto/venv.sh"
  fi

  printf "$(_ 'Installed Linto for all users in %s')\n" "$prefix"
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) printf "$(_ 'Add %s to the PATH of your users if it is not there already.')\n" "$bin_dir" ;;
  esac
}

# ============================================================================
# --user
# ============================================================================
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

configure_shell() {
  local shell_name=$1 fish_completion stale_line temporary profile env_line
  fish_completion="$user_data_dir/completions/linto.fish"
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

  # The generated fish completion (written by build) supersedes the static one in
  # the checkout; drop an earlier line sourcing the static file so rules are not defined twice.
  if [[ "$shell_name" == fish && "$fish_completion" == "$user_data_dir/completions/linto.fish" ]]; then
    stale_line="source \"$completion_dir/linto.fish\""
    if grep -Fqx -- "$stale_line" "$config_file"; then
      temporary=$(mktemp "${config_file}.linto.XXXXXX")
      grep -Fvx -- "$stale_line" "$config_file" > "$temporary" || true
      chmod --reference="$config_file" "$temporary" 2>/dev/null || true
      mv -- "$temporary" "$config_file"
    fi
  fi

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

  printf "$(_ 'Configured Linto for %s in %s')\n" "$shell_name" "$config_file"
  case "$shell_name" in
    ksh|sh) printf "$(_ 'Reload with: . %q')\n" "$config_file" ;;
    *) printf "$(_ 'Reload with: source %q')\n" "$config_file" ;;
  esac
}

install_user() {
  # Build first: the generated wrappers and fish completion are what the shells point at.
  if [[ "$install_man" == true ]]; then
    "$repo_dir/groups/linto/addman.sh"
  else
    "$repo_dir/groups/linto/build.sh"
  fi
  local shell_name
  for shell_name in "${selected[@]}"; do
    configure_shell "$shell_name"
  done
  if [[ "$make_venv" == true ]]; then
    "$repo_dir/groups/linto/venv.sh"
  fi
}

if [[ "$mode" == system ]]; then
  install_system
else
  install_user
fi
