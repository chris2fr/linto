#!/usr/bin/env bash
# linto-complete: none
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [-h|--help]

Find the nearest ancestor _quarto.yml, read project.output-dir, and open the
corresponding output directory for the current directory.
EOF
}

case "${1-}" in
    -h|--help) usage; exit 0 ;;
    *) if [[ $# -ne 0 ]]; then usage >&2; exit 2; fi ;;
esac

launch_dir=$(pwd -P)
search_dir=$launch_dir
quarto_yml=
while :; do
    if [[ -f "$search_dir/_quarto.yml" ]]; then
        quarto_yml="$search_dir/_quarto.yml"
        break
    fi
    [[ "$search_dir" == / ]] && break
    search_dir=$(dirname -- "$search_dir")
done

if [[ -z "$quarto_yml" ]]; then
    printf 'error: no _quarto.yml found in %s or its parent directories\n' "$launch_dir" >&2
    exit 1
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$quarto_yml")" && pwd -P)
output_dir=$(awk '
    function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        return value
    }
    /^[[:space:]]*(#.*)?$/ { next }
    {
        indent = match($0, /[^ ]/) - 1
        line = substr($0, indent + 1)
        if (!in_project && line ~ /^project:[[:space:]]*(#.*)?$/) {
            in_project = 1
            project_indent = indent
            next
        }
        if (in_project && indent <= project_indent) exit
        if (in_project && indent > project_indent && line ~ /^output-dir:[[:space:]]*/) {
            sub(/^output-dir:[[:space:]]*/, "", line)
            line = trim(line)
            quote = substr(line, 1, 1)
            if ((quote == "\"" || quote == sprintf("%c", 39)) && substr(line, length(line), 1) == quote) {
                line = substr(line, 2, length(line) - 2)
            } else {
                sub(/[[:space:]]+#.*/, "", line)
                line = trim(line)
            }
            print line
            exit
        }
    }
' "$quarto_yml")

if [[ -z "$output_dir" ]]; then
    printf 'error: project.output-dir not found in %s\n' "$quarto_yml" >&2
    exit 1
fi

if [[ "$output_dir" == /* ]]; then
    output_root=$output_dir
else
    output_root="$project_dir/$output_dir"
fi

if [[ "$launch_dir" == "$project_dir" ]]; then
    relative_dir=.
else
    relative_dir=${launch_dir#"$project_dir"/}
fi

target_dir="$output_root/$relative_dir"
exec firefox "$target_dir"
