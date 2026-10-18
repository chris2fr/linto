#!/bin/sh
# linto-complete: opt -s,--shell choices:fish,bash,sh,ksh,zsh,all Shell to update (default: the current one)

python3 "$(dirname "$0")/lib/aliases.py" "$@"
