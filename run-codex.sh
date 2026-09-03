#!/usr/bin/env bash
set -euo pipefail

codex_auth=${HOME}/.codex/auth.json

if [[ ! -r $codex_auth ]]; then
    echo 'Log in on the host with codex login before starting the container.' >&2
    exit 1
fi

# Resolve the real script location, even when invoked through ~/bin/run-codex.sh
script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
repo_root=$(cd -- "$(dirname -- "$script_path")" && pwd -P)

codex_uid=${CODEX_UID:-$(id -u)}
codex_gid=${CODEX_GID:-$(id -g)}

if [[ ${1:-} == --bash ]]; then
    shift
    command=(bash "$@")
else
    command=(codex --sandbox danger-full-access --ask-for-approval on-request "$@")
fi

exec docker run --rm --interactive --tty \
    --hostname docker \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --network bridge \
    --tmpfs "/home/codex:rw,nosuid,nodev,size=1g,uid=${codex_uid},gid=${codex_gid},mode=0700" \
    --tmpfs "/tmp:rw,nosuid,nodev,size=4g,uid=${codex_uid},gid=${codex_gid},mode=1777" \
    --mount "type=bind,src=${codex_auth},dst=/run/codex/auth.json,readonly" \
    --mount "type=bind,src=${repo_root},dst=/home/codex" \
    --mount "type=bind,src=${repo_root},dst=/home/codex/workspace" \
    --workdir /home/codex/workspace \
    --env CODEX_HOME=/home/codex/.codex \
    --env UV_CACHE_DIR=/tmp/uv-cache \
    codex:0.149.0 \
    "${command[@]}"
