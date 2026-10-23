#!/usr/bin/env bash
# linto-complete: flag --user Install for the current user
# linto-complete: flag --system Install for all users
# linto-complete: opt --shell choices:all,fish,bash,ksh,sh,zsh Shell to configure with --user (default: all)
# linto-complete: opt --prefix dir Installation prefix (default: ~/.local with --user, /usr/local with --system)
# linto-complete: opt --sysconfdir dir Directory holding linto/linto.yml with --system (default: /etc)
# linto-complete: flag --no-man Do not install the man page
# linto-complete: flag --venv Also create the Python environment (linto linto venv)
# linto-complete: flag --remove-user-install With --system, delete your user installation
# linto-complete: flag --keep-user-install With --system, keep your user installation
set -euo pipefail

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto install [--user | --system] [--shell SHELL]... [--prefix DIR]
                           [--sysconfdir DIR] [--no-man] [--venv]
                           [--remove-user-install | --keep-user-install] [-h|--help]

Install Linto, for the current user (--user) or for all users (--system). When
neither is given, ask which. Either way Linto is copied out of this checkout and
the commands, completions and PATH entries point at the installed copy only;
run the installer again from a checkout to upgrade.

--user installs to PREFIX/lib/linto (default ~/.local), builds the command
wrappers, completions and man pages (linto linto build), and adds PREFIX/bin and
the per-user wrapper directory to PATH and installs shell completion for each
selected shell. Configuration lines are not duplicated, and lines that pointed at
a checkout are replaced. It also creates ~/.linto.yml from the template
etc/linto.yml when you have no user configuration, and warns if a system-wide
installation exists.

--system installs to PREFIX/lib/linto (default /usr/local), builds its wrappers
into PREFIX/share/linto, links the commands into PREFIX/bin, and installs the
completions and man pages under PREFIX/share. When PREFIX is not writable by you
and you are not root, the steps that need it run through sudo. The installed
config.yml comes from the neutral template etc/config.yml, not from this checkout,
and /etc/linto/linto.yml is created from etc/linto.yml unless it already exists.
If you also have a user installation, it asks whether to delete it.

On NixOS, no files are changed; the matching NixOS options are printed instead.

Shells: fish, bash, ksh, sh, zsh (default: all of them). Completion is installed
for zsh, bash and fish; ksh and sh only get the PATH entries (ksh through
~/.kshrc, loaded via ENV from ~/.profile; sh through ~/.profile).

Options:
  --user         Install for the current user.
  --system       Install for all users.
  --shell SHELL  Shell to configure with --user: fish, bash, ksh, sh, zsh or all;
                 repeat it or separate shells with commas (default: all).
  --prefix DIR   Installation prefix (default: ~/.local with --user, /usr/local with --system).
  --sysconfdir DIR  Directory holding linto/linto.yml with --system (default: /etc).
  --no-man       Do not install the man page.
  --venv         Also create the Python environment (linto linto venv).
  --remove-user-install  With --system, delete your user installation without asking.
  --keep-user-install    With --system, keep your user installation without asking.
  -h, --help     Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"
. "$script_dir/lib/installer.sh"

mode=
shells=()
prefix=
sysconfdir=/etc
install_man=true
make_venv=false
user_install_policy=ask
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --user) mode=user; shift ;;
    --system) mode=system; shift ;;
    --no-man) install_man=false; shift ;;
    --man) install_man=true; shift ;;
    --venv) make_venv=true; shift ;;
    --remove-user-install) user_install_policy=remove; shift ;;
    --keep-user-install) user_install_policy=keep; shift ;;
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
    --sysconfdir)
      [[ $# -ge 2 ]] || die_usage "option %s needs an argument" "$1"
      sysconfdir=$2
      shift 2
      ;;
    --sysconfdir=*) sysconfdir=${1#*=}; shift ;;
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
if [[ "$mode" == user && "$sysconfdir" != /etc ]]; then
  die_usage "%s only applies with %s" "--sysconfdir" "--system"
fi
if [[ "$mode" == system && ${#shells[@]} -gt 0 ]]; then
  die_usage "%s only applies with %s" "--shell" "--user"
fi
if [[ "$mode" == user && "$user_install_policy" != ask ]]; then
  die_usage "%s only applies with %s" "--remove-user-install and --keep-user-install" "--system"
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
init_user_paths

# install_tree LIBDIR BINDIR VERSION: copy this checkout to LIBDIR and add the dispatcher launcher.
install_tree() {
  local lib_dir=$1 bin_dir=$2 version=$3 marker
  marker="$lib_dir/.linto-install"
  case "$lib_dir" in /*) ;; *) die "the prefix must be an absolute path: %s" "$lib_dir" ;; esac
  if [[ -d "$lib_dir" && "$(CDPATH= cd -- "$lib_dir" && pwd -P)" == "$repo_dir" ]]; then
    die "run the installer from a checkout, not from the installed copy: %s" "$lib_dir"
  fi
  if [[ -e "$lib_dir" && ! -f "$marker" ]]; then
    die "refusing to replace %s: not a Linto installation" "$lib_dir"
  fi
  umask 022
  printf "$(_ 'Installing Linto in %s')\n" "$lib_dir"
  priv rm -rf -- "$lib_dir"
  priv mkdir -p -- "$lib_dir" "$bin_dir"
  copy_tree "$repo_dir" "$lib_dir"
  printf '%s\n' "$version" | priv tee "$marker" >/dev/null
  # The dispatcher must run from its own tree, so the command is a launcher.
  printf '#!/bin/sh\nexec %q "$@"\n' "$lib_dir/bin/linto" | priv tee "$bin_dir/linto" >/dev/null
  priv chmod 0755 "$bin_dir/linto"
}

checkout_version=$(python3 "$repo_dir/lib/config.py" "$repo_dir/config.yml" version 2>/dev/null || echo unknown)

# ============================================================================
# --system
# ============================================================================
install_system() {
  local prefix=${prefix:-/usr/local}
  local lib_dir="$prefix/lib/linto" share_dir="$prefix/share" bin_dir="$prefix/bin" entry target
  local system_config="$sysconfdir/linto/linto.yml" user_lib answer

  setup_privileges "$prefix"
  install_tree "$lib_dir" "$bin_dir" "$checkout_version"

  # The installed tree gets the neutral defaults, not this checkout's personal config.yml.
  sed "s/^version:.*/version: $checkout_version/" "$repo_dir/etc/config.yml" |
    priv tee "$lib_dir/config.yml" >/dev/null

  # System-wide local configuration: created from the template, never overwritten.
  if [[ -e "$system_config" ]]; then
    printf "$(_ 'Kept the existing %s')\n" "$system_config"
  else
    priv mkdir -p -- "$sysconfdir/linto"
    priv install -m 0644 -- "$repo_dir/etc/linto.yml" "$system_config"
    printf "$(_ 'Created %s')\n" "$system_config"
  fi

  if [[ "$make_venv" == true ]]; then
    priv env PATH="$PATH" "$lib_dir/groups/linto/venv.sh"
  fi

  # Build the wrappers, completions and man pages for the whole system, ignoring
  # the configuration of whoever runs the installation.
  priv env PATH="$PATH" HOME=/var/empty XDG_CONFIG_HOME=/var/empty XDG_DATA_HOME="$share_dir" \
    "$lib_dir/groups/linto/build.sh" >/dev/null

  # Links to the generated wrappers, which already hold absolute paths.
  for entry in "$share_dir/linto/bin"/*; do
    [[ -f "$entry" ]] || continue
    priv ln -sfn -- "$entry" "$bin_dir/${entry##*/}"
  done
  for entry in "$bin_dir"/linto-*; do                # wrappers of groups that no longer exist
    [[ -L "$entry" && ! -e "$entry" ]] || continue
    target=$(readlink -- "$entry")
    [[ "$target" == "$share_dir/linto/bin/"* ]] && priv rm -f -- "$entry"
  done

  # Completions.
  priv mkdir -p -- "$share_dir/bash-completion/completions" "$share_dir/zsh/site-functions" \
    "$share_dir/fish/vendor_completions.d"
  printf 'source %q\n' "$lib_dir/completions/linto.bash" |
    priv tee "$share_dir/bash-completion/completions/linto" >/dev/null
  priv ln -sfn -- "$lib_dir/completions/_linto" "$share_dir/zsh/site-functions/_linto"
  printf 'source %q\n' "$share_dir/linto/completions/linto.fish" |
    priv tee "$share_dir/fish/vendor_completions.d/linto.fish" >/dev/null

  # Man pages.
  if [[ "$install_man" == true ]]; then
    priv mkdir -p -- "$share_dir/man/man1"
    for entry in "$share_dir/linto/man/man1"/linto*.1; do
      [[ -f "$entry" ]] && priv install -m 0644 -- "$entry" "$share_dir/man/man1/${entry##*/}"
    done
  fi

  printf "$(_ 'Installed Linto for all users in %s')\n" "$prefix"
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) printf "$(_ 'Add %s to the PATH of your users if it is not there already.')\n" "$bin_dir" ;;
  esac

  # The system installation makes the user's own copy redundant: offer to delete it.
  user_lib="$default_user_prefix/lib/linto"
  if [[ -f "$user_lib/.linto-install" ]]; then
    case "$user_install_policy" in
      remove) answer=y ;;
      keep) answer=n ;;
      *)
        if [[ -t 0 && -t 1 ]]; then
          printf "$(_ 'You also have a user installation in %s. Delete it? [y/N]') " "$user_lib"
          read -r answer || answer=n
        else
          answer=n
          printf "$(_ 'You also have a user installation in %s; remove it with: linto linto uninstall --user')\n" "$user_lib"
        fi
        ;;
    esac
    case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
      y|yes|o|oui) "$repo_dir/groups/linto/uninstall.sh" --user --yes ;;
    esac
  fi
}

# ============================================================================
# --user
# ============================================================================
configure_shell() {
  local shell_name=$1 lib_dir=$2 bin_dir=$3 temporary profile env_line

  # Replace lines that point at this checkout with lines for the installed copy.
  if [[ "$repo_dir" != "$lib_dir" ]]; then
    remove_shell_lines "$shell_name" "$repo_dir/bin" "$repo_dir/completions"
  fi

  shell_lines "$shell_name" "$bin_dir" "$lib_dir/completions"
  mkdir -p -- "$(dirname -- "$config_file")"
  [[ -f "$config_file" ]] || : > "$config_file"

  # The generated fish completion supersedes the static file of the installed tree.
  [[ -z "$static_fish_line" || "$completion_line" == "$static_fish_line" ]] ||
    remove_line "$config_file" "$static_fish_line"

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

install_user() {
  local prefix=${prefix:-$default_user_prefix}
  local lib_dir="$prefix/lib/linto" bin_dir="$prefix/bin" shell_name system_prefixes

  install_tree "$lib_dir" "$bin_dir" "$checkout_version"

  if [[ "$make_venv" == true ]]; then
    "$lib_dir/groups/linto/venv.sh"
  fi

  # Build from the installed copy, so the generated wrappers point at it.
  if [[ "$install_man" == true ]]; then
    XDG_DATA_HOME="$data_home" "$lib_dir/groups/linto/addman.sh"
  else
    XDG_DATA_HOME="$data_home" "$lib_dir/groups/linto/build.sh"
  fi

  for shell_name in "${selected[@]}"; do
    configure_shell "$shell_name" "$lib_dir" "$bin_dir"
  done

  # A new user configuration, from the template, unless one already exists.
  if [[ ! -e "$HOME/.linto.yml" && ! -e "$config_home/linto/config.yml" ]]; then
    install -m 0644 -- "$repo_dir/etc/linto.yml" "$HOME/.linto.yml"
    printf "$(_ 'Created %s')\n" "$HOME/.linto.yml"
  fi

  system_prefixes=$(find_system_installs)
  if [[ -n "$system_prefixes" ]]; then
    while IFS= read -r prefix_found; do
      printf "$(_ 'Warning: a system-wide Linto is installed in %s. Your user installation in %s takes precedence for you; to use the system one, run: linto linto uninstall --user')\n" \
        "$prefix_found/lib/linto" "$lib_dir" >&2
    done <<<"$system_prefixes"
  elif packaged=$(find_packaged_install); then
    printf "$(_ 'Warning: Linto is also installed system-wide (%s). Your user installation takes precedence for you.')\n" "$packaged" >&2
  fi
}

if [[ "$mode" == system ]]; then
  install_system
else
  install_user
fi
