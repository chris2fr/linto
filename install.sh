#!/bin/sh
# Linto bootstrap installer: downloads Linto from GitHub and runs its installer.
#
#   curl -fsSL https://raw.githubusercontent.com/chris2fr/linto/main/install.sh | sh -s -- --user
#   wget -qO-  https://raw.githubusercontent.com/chris2fr/linto/main/install.sh | sh -s -- --system
#
# Every argument goes to the installer, groups/linto/lib/install.sh (run `sh install.sh --help`
# to list them); without --user or --system it asks. `linto linto update` runs this script again
# from the installed copy.
# `sh install.sh --local ...` installs the checkout this script is in, without downloading. Environment (all optional):
#   LINTO_REPO          GitHub repository (default: chris2fr/linto)
#   LINTO_REF           branch, tag or commit to install (default: main)
#   LINTO_GITHUB_TOKEN  token for a private repository or to avoid API rate limits
#   LINTO_ARCHIVE_URL   tarball to download (default: the GitHub archive of REPO at REF)
#   LINTO_COMMIT_URL    URL returning the commit hash of REF (default: the GitHub API)
# `sh install.sh --latest-commit` prints the hash of the latest commit of REF and exits.
#
# Needs: sh, curl or wget, tar, bash and python3 (with PyYAML, or network access to install it).

set -eu

repo=${LINTO_REPO:-chris2fr/linto}
ref=${LINTO_REF:-main}
archive_url=${LINTO_ARCHIVE_URL:-https://github.com/$repo/archive/$ref.tar.gz}
commit_url=${LINTO_COMMIT_URL:-https://api.github.com/repos/$repo/commits/$ref}
token=${LINTO_GITHUB_TOKEN:-}

say() { printf 'linto-install: %s\n' "$*" >&2; }
fail() { say "$*"; exit 1; }

# fetch URL [ACCEPT]: write the URL to standard output.
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL ${token:+-H "Authorization: Bearer $token"} ${2:+-H "Accept: $2"} "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- ${token:+--header="Authorization: Bearer $token"} ${2:+--header="Accept: $2"} "$1"
  else
    fail "curl or wget is required"
  fi
}

latest_commit() {
  fetch "$commit_url" "application/vnd.github.sha" | tr -d '[:space:]'
}

main() {
  if [ "${1-}" = --latest-commit ]; then
    latest_commit || fail "cannot read the latest commit from $commit_url"
    echo
    exit 0
  fi

  if [ "${1-}" = --local ]; then
    shift
    here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    [ -f "$here/groups/linto/lib/install.sh" ] || fail "--local must be used from a Linto checkout"
    exec bash "$here/groups/linto/lib/install.sh" "$@"
  fi

  command -v tar >/dev/null 2>&1 || fail "tar is required"
  command -v bash >/dev/null 2>&1 || fail "bash is required"
  command -v python3 >/dev/null 2>&1 || fail "python3 is required"

  work=$(mktemp -d "${TMPDIR:-/tmp}/linto-install.XXXXXX")
  trap 'rm -rf "$work"' EXIT HUP INT TERM

  commit=$(latest_commit 2>/dev/null || true)
  say "downloading $repo ($ref${commit:+, $(printf '%.7s' "$commit")})"
  mkdir "$work/src"
  fetch "$archive_url" | tar -xzf - -C "$work/src" --strip-components=1 ||
    fail "cannot download or unpack $archive_url"
  [ -f "$work/src/groups/linto/lib/install.sh" ] || fail "$archive_url is not a Linto archive"

  # When piped from curl, standard input is the script: give the installer the terminal for its questions.
  if [ ! -t 0 ] && [ -t 1 ] && [ -r /dev/tty ]; then
    exec_input=/dev/tty
  else
    exec_input=/dev/stdin
  fi
  LINTO_SOURCE_REPO=$repo LINTO_SOURCE_REF=$ref LINTO_SOURCE_COMMIT=$commit \
    bash "$work/src/groups/linto/lib/install.sh" "$@" <"$exec_input"
}

# The whole script is parsed before anything runs, so it can safely replace its own file.
main "$@"
