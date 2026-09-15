#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 [-t target] [message ...]" >&2
}

if (($# == 0)); then
    tmux list-panes -a -F '#S:#I.#P  #{pane_current_command}'
    exit 0
fi

if [[ $1 != -t ]]; then
    usage
    exit 2
fi
shift

if (($# == 0)) || [[ -z $1 ]]; then
    echo 'Option -t requires a target.' >&2
    usage
    exit 2
fi

target=$1
shift

if (($# != 0)); then
    tmux send-keys -t "$target" -l -- "$*"
fi

tmux send-keys -t "$target" Enter
