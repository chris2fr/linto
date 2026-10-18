#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
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
                           Projects using the same root share this Zed data.
  -r, --reuse              Open in an existing Zed window (default).
  -n, --new                Always open a new workspace.
  -h, --help               Show this help message and exit.

Arguments:
  PATH                     File or directory to open (default: ./).

For a non-default user-data root, the first launch opens a temporary Zed window
and waits for you to close it while initializing shared languages and extensions.
Projects opened with the same --userdatadir share those components.
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
user_data_dir="$(cd "$zed_root" && pwd -P)/.zed"

if [[ "$mode" == "reuse" ]]; then
    open_flag="--existing"
else
    open_flag="--new"
fi

# User data may be shared between projects by choosing the same -u root. Keep
# each project's Zed config directory intact; only share languages/extensions.
shared_zed_dir="$HOME/.zed"
marker_file="$user_data_dir/.linto-version"

if [[ "$user_data_dir" != "$shared_zed_dir" ]]; then
    linto_config="$script_dir/config.yml"
    shared_version=$(python3 "$script_dir/lib/config.py" "$linto_config" version 2>/dev/null || true)
    if [[ -z "$shared_version" ]]; then
        echo "zed: Linto version is missing from config.yml; refusing shared-data initialization" >&2
        exit 1
    fi

    marker_version=
    if [[ -f "$marker_file" ]]; then
        IFS= read -r marker_version < "$marker_file" || true
    fi

    if [[ "$marker_version" != "$shared_version" ]]; then
        if [[ -e "$marker_file" && ! -f "$marker_file" ]]; then
            printf 'zed: refusing to replace invalid marker path: %s\n' "$marker_file" >&2
            exit 1
        fi
        for shared_item in languages extensions; do
            local_path="$user_data_dir/$shared_item"
            shared_path="$shared_zed_dir/$shared_item"
            if [[ -e "$local_path" && ! -L "$local_path" && ! -d "$local_path" ]]; then
                printf 'zed: refusing to replace non-directory data path: %s\n' "$local_path" >&2
                exit 1
            fi
            if [[ -L "$local_path" && "$(readlink -f -- "$local_path" 2>/dev/null || true)" != "$(readlink -f -- "$shared_path" 2>/dev/null || true)" ]]; then
                printf 'zed: refusing to replace existing symlink: %s\n' "$local_path" >&2
                exit 1
            fi
            if [[ -e "$local_path" && ! -L "$local_path" && ! -f "$marker_file" ]]; then
                printf 'zed: refusing to remove unmarked local data path: %s (move it manually, or initialize from a clean .zed directory)\n' "$local_path" >&2
                exit 1
            fi
            if [[ -e "$shared_path" ]] || true; then
                # We will populate from shared_zed_dir directly below.
                true
            fi
        done
        printf 'Initializing shared Zed data in %s from %s...\n' "$user_data_dir" "$shared_zed_dir" >&2

        # Copy base configuration and state files from ~/.zed, excluding heavy/shared items
        for item in "$shared_zed_dir"/*; do
            item_name="$(basename "$item")"
            if [[ "$item_name" == "languages" || "$item_name" == "extensions" ]]; then
                continue
            fi
            target_item="$user_data_dir/$item_name"
            if [[ ! -e "$target_item" ]]; then
                cp -R "$item" "$target_item"
            fi
        done

        # Symlink shared items
        for shared_item in languages extensions; do
            local_path="$user_data_dir/$shared_item"
            shared_path="$shared_zed_dir/$shared_item"

            if [[ -L "$local_path" ]]; then
                continue
            fi
            if [[ -d "$local_path" ]]; then
                rm -rf -- "$local_path"
            fi
            [[ -e "$shared_path" ]] && ln -s "$shared_path" "$local_path" || true
        done

        marker_tmp="$marker_file.tmp.$$"
        if ! printf '%s\n' "$shared_version" > "$marker_tmp" || ! mv -f -- "$marker_tmp" "$marker_file"; then
            rm -f -- "$marker_tmp"
            echo "zed: failed to write shared-data marker: $marker_file" >&2
            exit 1
        fi
    fi
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
