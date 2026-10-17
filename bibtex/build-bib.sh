#!/usr/bin/env bash
# Generate one .bib file per piece configuration.
#
# Iterates over every staged config file matching `_pieces-*.yml` in the
# current directory, and runs the bibliography generator on each one,
# writing the result to a sibling `.bib` file whose name is derived from
# the input file.
#
# Expects to be run from a directory that contains the `_pieces-*.yml`
# files (the script resolves lib/generer-bib.py relative to itself).
#
# Run with `-h` or `--help` for usage information.

# Print usage information and exit.
usage() {
  cat <<'EOF'
Usage: build-bib.sh [-h|--help]

Generate one .bib file per staged piece configuration.

Scans the current directory for files matching `_pieces-*.yml` and runs
lib/generer-bib.py on each one, writing a sibling `<name>.bib`
file (e.g. `_pieces-ref-08.yml` -> `pieces-ref-08.bib`).

Must be run from a directory containing the `_pieces-*.yml` files.

Options:
  -h, --help   Show this help message and exit.
EOF
}

# Handle options: `-h`/`--help` prints usage, anything else is an error.
while getopts ":h-:" opt
do
  case "$opt" in
    h)
      usage
      exit 0
      ;;
    -)
      case "$OPTARG" in
        help)
          usage
          exit 0
          ;;
        *)
          echo "Unknown option: --$OPTARG" >&2
          usage >&2
          exit 2
          ;;
      esac
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# -e: exit immediately if any command fails
# -u: treat unset variables as an error
# -o pipefail: a pipeline fails if any command in it fails
set -euo pipefail

# Locate the bibliography generator next to this script, so build-bib.sh
# works regardless of the directory it is run from.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
generator="$script_dir/lib/generer-bib.py"

# Loop over each staged piece file (unquoted glob so the shell expands it).
for i in _pieces-*.yml
do
  echo "$i"
  base="${i#_}"       # _pieces-ref-08.yml  ->  pieces-ref-08.yml
  base="${base%.yml}" # pieces-ref-08.yml   ->  pieces-ref-08
  # Generate `pieces-ref-08.bib` from `_pieces-ref-08.yml`.
  python3 "$generator" "$i" "$base.bib"
done