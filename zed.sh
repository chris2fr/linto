#!/usr/bin/env bash
set -euo pipefail

userdatadir=""
projectdir=""
mode="reuse"

usage() {
    cat <<'EOF'
Usage: zed.sh [OPTIONS] [PATH]

Open PATH in Zed. PATH may be a file or a directory.

If PATH is a file, its parent directory is opened as the project and the
file itself is opened as the focused buffer. If PATH is a directory, the
directory is opened as the project.

Options:
  -p, --projectdir DIR     Project directory to open in Zed
                           (overrides the directory derived from PATH).
  -u, --userdatadir DIR    Root directory above ".zed"; the user data dir is
                           always "$DIR/.zed". Defaults to the project directory.
  -r, --reuse              Open in an existing Zed window (default).
  -n, --new                Always open a new workspace.
  -h, --help               Show this help message and exit.

Arguments:
  PATH                     File or directory to open (default: ./).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -p|--projectdir)
            if [[ $# -lt 2 ]]; then
                echo "error: $1 requires an argument" >&2
                exit 1
            fi
            projectdir="$2"
            shift 2
            ;;
        --projectdir=*)
            projectdir="${1#*=}"
            shift
            ;;
        -p?*)
            projectdir="${1#-p}"
            shift
            ;;
        -u|--userdatadir)
            if [[ $# -lt 2 ]]; then
                echo "error: $1 requires an argument" >&2
                exit 1
            fi
            userdatadir="$2"
            shift 2
            ;;
        --userdatadir=*)
            userdatadir="${1#*=}"
            shift
            ;;
        -u?*)
            userdatadir="${1#-u}"
            shift
            ;;
        -r|--reuse)
            mode="reuse"
            shift
            ;;
        -n|--new)
            mode="new"
            shift
            ;;
        -[a-zA-Z]*)
            echo "error: unknown option: $1" >&2
            exit 1
            ;;
        *)
            target="$1"
            shift
            ;;
    esac
done

# Default to the current directory when no argument is given.
target="${target:-./}"

# Determine the project directory: explicit -p wins, else derive from target.
if [[ -n "$projectdir" ]]; then
    project_dir="$(cd "$projectdir" && pwd)"
else
    if [[ -f "$target" ]]; then
        file_basename="$(basename "$target")"
        project_dir="$(cd "$(dirname "$target")" && pwd)"
    else
        file_basename=""
        project_dir="$(cd "$target" && pwd)"
    fi
fi

# Determine the ".zed" root: explicit -u wins, else default to project dir.
if [[ -n "$userdatadir" ]]; then
    zed_root="$(cd "$userdatadir" && pwd)"
else
    zed_root="$project_dir"
fi

user_data_dir="$zed_root/.zed"

mkdir -p "$user_data_dir"

if [[ "$mode" == "reuse" ]]; then
    open_flag="--existing"
else
    open_flag="--new"
fi

# Run from the project directory so pwd supplies the absolute project path to Zed.
(
    cd "$project_dir"
    user_data_dir="$(cd "$zed_root" && pwd)/.zed"

    if [[ -n "${file_basename:-}" ]]; then
        zeditor --user-data-dir "$user_data_dir" "$open_flag" "$(pwd)" "$file_basename"
    else
        zeditor --user-data-dir "$user_data_dir" "$open_flag" "$(pwd)"
    fi
)
