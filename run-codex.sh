#!/usr/bin/env bash
set -euo pipefail

codex_uid=${CODEX_UID:-$(id -u)}
codex_gid=${CODEX_GID:-$(id -g)}
codex_home=${CODEX_DOCKER_HOME:-${HOME}/.codex-docker}
codex_image=${CODEX_IMAGE:-codex:0.154.0}
launcher_path=$(readlink -f -- "${BASH_SOURCE[0]}")
launcher_dir=$(dirname -- "$launcher_path")
container_home=${CODEX_CONTAINER_HOME:-"${launcher_dir}/home"}
workspace_dir=$(pwd -P)

mkdir -p -- "$codex_home"
if [[ ! -w $codex_home ]]; then
    echo "Codex state directory is not writable: $codex_home" >&2
    exit 1
fi

if [[ ! -d $container_home ]] || [[ ! -w $container_home ]]; then
    echo "Container home directory is missing or not writable: $container_home" >&2
    exit 1
fi

docker_args=(
    run --rm --interactive --tty
    --hostname docker
    --cap-drop ALL
    --security-opt no-new-privileges
    --network bridge
    --user "${codex_uid}:${codex_gid}"
    --tmpfs "/tmp:rw,nosuid,nodev,size=4g,uid=${codex_uid},gid=${codex_gid},mode=1777"
    --mount "type=bind,src=/etc/localtime,dst=/etc/localtime,readonly"
    --mount "type=bind,src=${workspace_dir},dst=/home/codex/workspace"
    --mount "type=bind,src=${container_home},dst=/home/codex"
    --mount "type=bind,src=${codex_home},dst=/home/codex/.codex"
    --workdir /home/codex/workspace
    --env CODEX_HOME=/home/codex/.codex
    --env UV_CACHE_DIR=/tmp/uv-cache
    # Codex tool shells may replace the image PATH, so pass the required paths
    # explicitly at container start as well.
    --env PATH=/home/codex/bin:/opt/elan/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin
)

# Request GPU access only when the host exposes an NVIDIA GPU.
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    docker_args+=(--gpus all)
fi

if [[ ${1:-} == --bash ]]; then
    shift
    docker_args+=(--entrypoint bash "$codex_image" "$@")
else
    docker_args+=("$codex_image" --sandbox danger-full-access --ask-for-approval never "$@")
fi

exec docker "${docker_args[@]}"
