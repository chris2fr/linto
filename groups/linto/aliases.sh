#!/bin/sh
# linto-complete: opt -s,--shell choices:fish,bash,sh,ksh,zsh,all

python3 "$(dirname "$0")/lib/aliases.py" "$@"
