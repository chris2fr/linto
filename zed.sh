#!/usr/bin/env bash
set -euo pipefail

mkdir -p .zed
zeditor --user-data-dir "$PWD/.zed" --new "$PWD"
