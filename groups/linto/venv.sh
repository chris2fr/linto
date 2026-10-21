#!/bin/sh
# linto-complete: flag --recreate Delete and rebuild the environment
# linto-complete: opt --python value Python interpreter used to create the environment
set -eu

usage() {
  _ "$(cat <<'EOF'
Usage: linto linto venv [-h|--help] [--recreate] [--python PYTHON]

Create the Python environment Linto runs with, $LINTO_ROOT/.venv, and install
the packages listed in requirements.txt into it. Once it exists, the linto
dispatcher puts it first on PATH, so every command uses it. Run the command
again to install new requirements.

Set LINTO_NO_VENV=1 to ignore the environment for one run.

Options:
  --recreate       Delete the environment and build it again.
  --python PYTHON  Interpreter to create it with (default: python3).
  -h, --help       Show this help and exit.
EOF
)"
  echo
}

. "$(dirname -- "$0")/../../lib/common.sh"

python=python3
recreate=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --recreate) recreate=1; shift ;;
    --python)
      [ "$#" -ge 2 ] || die_usage "option %s needs an argument" "$1"
      python=$2
      shift 2
      ;;
    --python=*) python=${1#*=}; shift ;;
    -?*) die_usage "unknown option: %s" "$1" ;;
    *) die_usage "unexpected argument: %s" "$1" ;;
  esac
done

root=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
venv=$root/.venv
requirements=$root/requirements.txt
[ -f "$requirements" ] || die "requirements file not found: %s" "$requirements"
[ -w "$root" ] || die "cannot write to %s (read-only installation?)" "$root"

# Build with an interpreter that is not the environment being replaced.
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF "$venv/bin" | paste -sd: -)
export PATH
command -v "$python" >/dev/null 2>&1 || die "%s is required" "$python"

if [ "$recreate" -eq 1 ] && [ -e "$venv" ]; then
  [ -f "$venv/pyvenv.cfg" ] || die "refusing to delete %s: not a Python environment" "$venv"
  rm -rf -- "$venv"
fi

if [ ! -x "$venv/bin/python3" ]; then
  printf "$(_ 'Creating %s')\n" "$venv"
  "$python" -m venv "$venv" || die "could not create the environment in %s" "$venv"
fi
printf '%s\n' "$(_ 'Installing the requirements...')"
"$venv/bin/python3" -m pip install --quiet --disable-pip-version-check -r "$requirements" ||
  die "could not install the requirements from %s" "$requirements"
printf "$(_ 'Linto will now run with %s')\n" "$venv/bin/python3"
