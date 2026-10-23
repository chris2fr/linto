# installer.sh -- helpers shared by install.sh and uninstall.sh (bash, sourced after lib/common.sh).

ALL_SHELLS=(fish bash ksh sh zsh)

# --- privileges --------------------------------------------------------------
# Run a command as root when the installation needs it: directly when already
# root or when the prefix is writable, through sudo otherwise.
use_sudo=false
priv() {
  if [[ "$use_sudo" == true ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

# True when the current user can create PREFIX and everything below it.
prefix_is_writable() {
  local path=$1 entry
  while [[ ! -e "$path" ]]; do path=$(dirname -- "$path"); done
  [[ -d "$path" && -w "$path" ]] || return 1
  for entry in "$1/bin" "$1/lib" "$1/lib/linto" "$1/share"; do
    [[ ! -e "$entry" || -w "$entry" ]] || return 1
  done
}

# setup_privileges PREFIX: decide whether sudo is needed and ask for it once.
setup_privileges() {
  local prefix=$1
  if [[ "${LINTO_INSTALL_SUDO:-}" == always ]]; then
    use_sudo=true
  elif [[ "$(id -u)" -ne 0 ]] && ! prefix_is_writable "$prefix"; then
    use_sudo=true
  fi
  if [[ "$use_sudo" == true ]]; then
    command -v sudo >/dev/null 2>&1 ||
      die "cannot write to %s (run as root, or choose another --prefix)" "$prefix"
    printf "$(_ 'Writing to %s needs root: using sudo.')\n" "$prefix" >&2
    sudo -v || die "sudo failed"
  fi
}

# --- per-user paths ----------------------------------------------------------
init_user_paths() {
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
  default_user_prefix="$HOME/.local"
}

# --- shell start-up lines ----------------------------------------------------
# shell_lines SHELL BINDIR COMPDIR
# Sets config_file, completion_line, static_fish_line, init_line and path_line for a
# Linto whose commands are in BINDIR (plus the user's generated wrappers) and whose
# completion files are in COMPDIR.
shell_lines() {
  local shell_name=$1 bindir=$2 compdir=$3 fish_completion
  fish_completion="$user_data_dir/completions/linto.fish"
  completion_line=''
  static_fish_line=''
  init_line=''
  path_line="export PATH=\"$bindir:$user_bin_dir:\$PATH\""
  case "$shell_name" in
    zsh)
      config_file="${ZDOTDIR:-$HOME}/.zshrc"
      completion_line="fpath=(\"$compdir\" \$fpath)"
      init_line='autoload -Uz compinit && compinit'
      ;;
    bash)
      config_file="$HOME/.bashrc"
      completion_line="source \"$compdir/linto.bash\""
      ;;
    fish)
      config_file="$config_home/fish/config.fish"
      static_fish_line="source \"$compdir/linto.fish\""
      [[ -f "$fish_completion" ]] || fish_completion="$compdir/linto.fish"
      completion_line="source \"$fish_completion\""
      path_line="fish_add_path \"$bindir\" \"$user_bin_dir\""
      ;;
    ksh) config_file="$HOME/.kshrc" ;;
    sh) config_file="$HOME/.profile" ;;
  esac
}

# remove_line FILE LINE: delete the lines of FILE that are exactly LINE.
remove_line() {
  local file=$1 line=$2 temporary
  [[ -n "$line" && -f "$file" ]] || return 0
  grep -Fqx -- "$line" "$file" || return 0
  temporary=$(mktemp "${file}.linto.XXXXXX")
  grep -Fvx -- "$line" "$file" > "$temporary" || true
  chmod --reference="$file" "$temporary" 2>/dev/null || true
  mv -- "$temporary" "$file"
}

# remove_shell_lines SHELL BINDIR COMPDIR: take out the lines shell_lines would add.
remove_shell_lines() {
  shell_lines "$1" "$2" "$3"
  remove_line "$config_file" "$path_line"
  remove_line "$config_file" "$completion_line"
  remove_line "$config_file" "$static_fish_line"
}

# --- finding installations ---------------------------------------------------
# Prefixes of system-wide installations made by `install --system` (one per line).
find_system_installs() {
  local prefix
  for prefix in ${LINTO_SYSTEM_PREFIXES:-/usr/local /usr /opt}; do
    [[ -f "$prefix/lib/linto/.linto-install" ]] && printf '%s\n' "$prefix"
  done
  return 0
}

# True when a Linto managed by NixOS or another package manager is on the system.
find_packaged_install() {
  local path
  for path in /run/current-system/sw/bin/linto /etc/profiles/per-user/"${USER:-nobody}"/bin/linto; do
    [[ -e "$path" ]] && { printf '%s\n' "$path"; return 0; }
  done
  return 1
}

# Copy the checkout to DIR (as root when needed), leaving out what an installation does not need.
copy_tree() {
  local from=$1 to=$2
  (cd "$from" && tar --exclude=./.git --exclude=./.venv --exclude=./tests \
      --exclude=__pycache__ --exclude='*.pyc' -cf - .) |
    priv tar --no-same-owner -xf - -C "$to"
}
