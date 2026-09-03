#!/usr/bin/env bash
set -euo pipefail

codex_auth=${HOME}/.codex/auth.json

if [[ ! -r $codex_auth ]]; then
    echo 'Log in on the host with codex login before starting the container.' >&2
    exit 1
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
codex_uid=${CODEX_UID:-$(id -u)}
codex_gid=${CODEX_GID:-$(id -g)}

if [[ ${1:-} == --bash ]]; then
    shift
    command=(bash "$@")
else
    command=(codex --sandbox danger-full-access --ask-for-approval on-request "$@")
fi

exec docker run --rm --interactive --tty \
    --gpus device=0 \
    --hostname docker \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --network bridge \
    --tmpfs "/home/codex:rw,nosuid,nodev,size=1g,uid=${codex_uid},gid=${codex_gid},mode=0700" \
    --tmpfs "/tmp:rw,nosuid,nodev,size=4g,uid=${codex_uid},gid=${codex_gid},mode=1777" \
    --mount "type=bind,src=${codex_auth},dst=/run/codex/auth.json,readonly" \
    --mount "type=bind,src=${repo_root},dst=/home/codex/relator" \
    --workdir /home/codex/relator \
    --env CODEX_HOME=/home/codex/.codex \
    --env "RELATOR_BENCHMARK_HOST=$(hostname)-docker" \
    --env UV_CACHE_DIR=/tmp/uv-cache \
    relator-codex:0.149.0 \
    "${command[@]}"
