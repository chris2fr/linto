# Source this file to add the Linux Tools bin directory to PATH.
# Usage: . /path/to/linto/internal/addpath.sh
# Supports Bash, zsh, and ksh93; see `linto` for tool documentation.

_linto_source=

if [ -n "${BASH_VERSION-}" ]; then
  _linto_source=${BASH_SOURCE[0]}
elif [ -n "${KSH_VERSION-}" ]; then
  eval '_linto_source=${.sh.file}' 2>/dev/null || _linto_source=
elif [ -n "${ZSH_VERSION-}" ]; then
  eval '_linto_source=${(%):-%x}' 2>/dev/null || _linto_source=
fi

if [ -z "$_linto_source" ]; then
  printf 'addlinto: cannot locate the sourced file in this shell. Use Bash, zsh, or ksh93.\n' >&2
  unset _linto_source
  return 1
fi

_linto_dir=$(CDPATH= cd -- "$(dirname -- "$_linto_source")/../../bin" && pwd -P) || {
  printf 'addlinto: could not determine the script directory\n' >&2
  unset _linto_source _linto_dir
  return 1
}

case ":${PATH-}:" in
  *":${_linto_dir}:"*) ;;
  *) PATH="${PATH:+$PATH:}${_linto_dir}" ;;
esac
export PATH
unset _linto_source _linto_dir
