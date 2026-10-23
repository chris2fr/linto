#!/usr/bin/env bash
# linto-complete: flag --check Only report whether an update is available
# linto-complete: opt --ref value Branch, tag or commit to update to (default: the one installed)
# linto-complete: flag --yes Do not ask for confirmation
set -euo pipefail

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto update [--check] [--ref REF] [--yes] [-h|--help]

Update this Linto installation from GitHub (chris2fr/linto). It looks up the latest
commit of the branch or tag Linto was installed from (main by default), and when it
differs from the installed one downloads it and runs the installer again with the same
choices as the original installation: user or system, prefix, shells, man page and
Python environment. The Python environment and its extras are kept. A system-wide
installation asks for sudo when it needs it.

Exit status with --check: 0 when up to date, 10 when an update is available.

Set LINTO_REPO, LINTO_REF and LINTO_GITHUB_TOKEN to use another repository, branch or
a token; see install.sh.

Options:
  --check      Only report whether an update is available.
  --ref REF    Update to this branch, tag or commit instead of the installed one.
  --yes, -y    Do not ask for confirmation.
  -h, --help   Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

check_only=false
assume_yes=false
ref_override=
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --check) check_only=true; shift ;;
    -y|--yes) assume_yes=true; shift ;;
    --ref)
      [[ $# -ge 2 ]] || die_usage "option %s needs an argument" "$1"
      ref_override=$2
      shift 2
      ;;
    --ref=*) ref_override=${1#*=}; shift ;;
    --) shift; [[ $# -eq 0 ]] || die_usage "unexpected argument: %s" "$1" ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *) die_usage "unexpected argument: %s" "$1" ;;
  esac
done

root=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
marker="$root/.linto-install"
[[ -f "$marker" ]] ||
  die "this copy of Linto was not made by the installer: install it with the command in the README, then update"

meta() {                                   # meta KEY: value of KEY= in the marker
  sed -n "s/^$1=//p" "$marker" | head -n 1
}
mode=$(meta mode); prefix=$(meta prefix); installed_commit=$(meta commit)
[[ -n "$mode" && -n "$prefix" ]] || die "the installation record %s is incomplete: reinstall Linto" "$marker"

export LINTO_REPO="${LINTO_REPO:-$(meta repo)}"
export LINTO_REF="${ref_override:-${LINTO_REF:-$(meta ref)}}"
[[ -f "$root/install.sh" ]] || die "bootstrap script not found: %s" "$root/install.sh"

latest=$(sh "$root/install.sh" --latest-commit) ||
  die "cannot read the latest commit of %s (%s)" "$LINTO_REPO" "$LINTO_REF"

if [[ "$latest" == "$installed_commit" && -z "$ref_override" ]]; then
  printf "$(_ 'Linto is up to date (%s, %s)')\n" "${installed_commit:0:7}" "$LINTO_REF"
  exit 0
fi
printf "$(_ 'Update available: %s -> %s (%s)')\n" "${installed_commit:0:7}" "${latest:0:7}" "$LINTO_REF"
[[ "$check_only" == true ]] && exit 10

if [[ "$assume_yes" != true ]]; then
  if [[ ! -t 0 || ! -t 1 ]]; then
    die_usage "refusing to update without confirmation: use --yes"
  fi
  printf '%s ' "$(_ 'Update now? [y/N]')"
  read -r answer || answer=n
  case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
    y|yes|o|oui) ;;
    *) exit 1 ;;
  esac
fi

# Same choices as the original installation.
args=("--$mode" --prefix "$prefix")
if [[ "$mode" == system ]]; then
  sysconfdir=$(meta sysconfdir)
  [[ -z "$sysconfdir" ]] || args+=(--sysconfdir "$sysconfdir")
else
  shells=$(meta shells)
  [[ -z "$shells" ]] || args+=(--shell "$shells")
fi
[[ "$(meta man)" == false ]] && args+=(--no-man)
[[ "$(meta venv)" == false ]] && args+=(--no-venv)

# The bootstrap script parses itself completely before running, so it can replace its own tree.
exec sh "$root/install.sh" "${args[@]}"
