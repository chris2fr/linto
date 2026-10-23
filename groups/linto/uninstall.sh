#!/usr/bin/env bash
# linto-complete: flag --user Remove the installation of the current user
# linto-complete: flag --system Remove the system-wide installation
# linto-complete: opt --prefix dir Installation prefix (default: ~/.local with --user, /usr/local with --system)
# linto-complete: flag --yes Do not ask for confirmation
set -euo pipefail

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto uninstall [--user | --system] [--prefix DIR] [--yes] [-h|--help]

Remove a Linto installation made by the installer (install.sh), for the current user
(--user) or for all users (--system). When neither is given, ask which.

--user deletes PREFIX/lib/linto (default ~/.local), the launcher in PREFIX/bin, the
generated wrappers, completions and man page in the per-user data directory, and the
lines that the installer added to your shell start-up files.

--system deletes PREFIX/lib/linto (default /usr/local), the commands linked into
PREFIX/bin, and the completions and man pages installed under PREFIX/share. When
PREFIX is not writable by you and you are not root, the steps that need it run
through sudo.

Your configuration (~/.linto.yml, ~/.config/linto, /etc/linto/linto.yml) and your own
groups are never deleted. Without --yes it asks for confirmation.

Options:
  --user         Remove the installation of the current user.
  --system       Remove the system-wide installation.
  --prefix DIR   Installation prefix (default: ~/.local with --user, /usr/local with --system).
  --yes, -y      Do not ask for confirmation.
  -h, --help     Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"
. "$script_dir/lib/installer.sh"

mode=
prefix=
assume_yes=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --user) mode=user; shift ;;
    --system) mode=system; shift ;;
    -y|--yes) assume_yes=true; shift ;;
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

if [[ -z "$mode" ]]; then
  if [[ -t 0 && -t 1 ]]; then
    printf '%s ' "$(_ 'Remove Linto for the current user or for all users (system)? [user/system]')"
    read -r answer || answer=
    case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
      u|user|utilisateur) mode=user ;;
      s|system|systeme|système) mode=system ;;
      *) die_usage "unknown answer: %s" "$answer" ;;
    esac
  else
    die_usage "choose --user or --system"
  fi
fi

repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
init_user_paths

confirm() {                                  # confirm MESSAGE
  [[ "$assume_yes" == true ]] && return 0
  if [[ ! -t 0 || ! -t 1 ]]; then
    die_usage "refusing to remove without confirmation: use --yes"
  fi
  printf '%s ' "$1"
  read -r answer || answer=n
  case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
    y|yes|o|oui) return 0 ;;
    *) return 1 ;;
  esac
}

# This script may live in the tree being deleted, so every message is translated
# before the tree goes and the tree is the last thing removed.
uninstall_user() {
  local prefix=${prefix:-$default_user_prefix}
  local lib_dir="$prefix/lib/linto" bin_dir="$prefix/bin" shell_name target man_link done_message kept_message

  if [[ ! -f "$lib_dir/.linto-install" ]]; then
    printf "$(_ 'No user installation found in %s')\n" "$lib_dir"
  fi
  confirm "$(printf "$(_ 'Remove the user installation of Linto (%s, its wrappers and the shell lines)? [y/N]')" "$lib_dir")" || exit 1

  # Shell start-up lines, for the installed copy and for a checkout that an older setup pointed at.
  for shell_name in "${ALL_SHELLS[@]}"; do
    remove_shell_lines "$shell_name" "$bin_dir" "$lib_dir/completions"
    remove_shell_lines "$shell_name" "$repo_dir/bin" "$repo_dir/completions"
  done
  # The generated fish completion line (not part of the shell lines above once its file is gone).
  shell_lines fish "$bin_dir" "$lib_dir/completions"
  remove_line "$config_file" "source \"$user_data_dir/completions/linto.fish\""

  # Generated wrappers, completions and man page of the per-user data directory (user groups stay).
  man_link="$data_home/man/man1/linto.1"
  if [[ -L "$man_link" && "$(readlink -f -- "$man_link")" == "$user_data_dir/"* ]]; then
    rm -f -- "$man_link"
  fi
  rm -rf -- "$user_data_dir/bin" "$user_data_dir/completions" "$user_data_dir/man"

  # The launcher, only if it is ours.
  if [[ -f "$bin_dir/linto" ]] && grep -Fq -- "$lib_dir/bin/linto" "$bin_dir/linto"; then
    rm -f -- "$bin_dir/linto"
  fi

  done_message=$(printf "$(_ 'Removed the user installation of Linto (%s)')" "$lib_dir")
  kept_message=$(printf "$(_ 'Kept your configuration (%s, %s) and your groups (%s)')" \
    "$HOME/.linto.yml" "$config_home/linto" "$user_data_dir/groups")
  if [[ -f "$lib_dir/.linto-install" ]]; then
    rm -rf -- "$lib_dir"
  elif [[ -e "$lib_dir" ]]; then
    target=$lib_dir
    printf "$(_ 'Kept %s: not a Linto installation')\n" "$target" >&2
  fi
  printf '%s\n%s\n' "$done_message" "$kept_message"
}

uninstall_system() {
  local prefix=${prefix:-/usr/local}
  local lib_dir="$prefix/lib/linto" share_dir="$prefix/share" bin_dir="$prefix/bin" entry target name
  local done_message kept_message

  [[ -f "$lib_dir/.linto-install" ]] || die "not a Linto installation: %s" "$lib_dir"
  setup_privileges "$prefix"
  confirm "$(printf "$(_ 'Remove the system-wide installation of Linto (%s and its commands, completions and man pages)? [y/N]')" "$lib_dir")" || exit 1

  # Commands linked from the generated wrappers, and the launcher.
  for entry in "$bin_dir"/linto*; do
    [[ -L "$entry" ]] || continue
    target=$(readlink -- "$entry")
    [[ "$target" == "$share_dir/linto/bin/"* ]] && priv rm -f -- "$entry"
  done
  if [[ -f "$bin_dir/linto" ]] && grep -Fq -- "$lib_dir/bin/linto" "$bin_dir/linto"; then
    priv rm -f -- "$bin_dir/linto"
  fi

  # Completions and man pages.
  priv rm -f -- "$share_dir/bash-completion/completions/linto" \
    "$share_dir/zsh/site-functions/_linto" "$share_dir/fish/vendor_completions.d/linto.fish"
  for entry in "$share_dir/linto/man/man1"/linto*.1; do
    [[ -f "$entry" ]] || continue
    name=${entry##*/}
    priv rm -f -- "$share_dir/man/man1/$name"
  done
  priv rm -rf -- "$share_dir/linto"

  done_message=$(printf "$(_ 'Removed the system-wide installation of Linto (%s)')" "$lib_dir")
  kept_message=$(printf "$(_ 'Kept the configuration files (for example /etc/linto/linto.yml) and the users'"'"' own files')")
  priv rm -rf -- "$lib_dir"
  printf '%s\n%s\n' "$done_message" "$kept_message"
}

if [[ "$mode" == system ]]; then
  uninstall_system
else
  uninstall_user
fi
