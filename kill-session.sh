#!/usr/bin/env bash

set -u

sid=${1:?Usage: $0 SESSION_ID}

mapfile -t pids < <(
    pgrep -f -- "$sid" |
    while read -r pid; do
        cmd=$(ps -p "$pid" -o args=)
        case "$cmd" in
            *"docker run"*|*"codex"*)
                echo "$pid"
                ;;
        esac
    done
)

if ((${#pids[@]} == 0)); then
    echo "No matching Codex/Docker process found for session $sid" >&2
    exit 1
fi

echo "Terminating processes for session $sid:"
ps -o pid,ppid,pgid,tty,stat,args -p "$(IFS=,; echo "${pids[*]}")"

kill -TERM "${pids[@]}"

for _ in {1..5}; do
    remaining=()
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            remaining+=("$pid")
        fi
    done

    ((${#remaining[@]} == 0)) && exit 0
    sleep 1
done

echo "Force-killing remaining processes: ${remaining[*]}" >&2
kill -KILL "${remaining[@]}"
