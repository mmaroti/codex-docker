#!/usr/bin/env bash
set -euo pipefail

# Resolve symlinks so a launcher linked into PATH still finds its policy.
script_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
seccomp_profile="$script_dir/codex-docker.seccomp.json"
if [[ ! -r $seccomp_profile ]]; then
    echo "Missing seccomp profile: $seccomp_profile" >&2
    exit 1
fi

codex_uid=${CODEX_UID:-$(id -u)}
codex_gid=${CODEX_GID:-$(id -g)}
codex_home=${CODEX_DOCKER_HOME:-${HOME}/.codex-docker}
codex_image=${CODEX_IMAGE:-codex:0.163.0}
workspace_dir=$(pwd -P)

mkdir -p -- "$codex_home"
if [[ ! -w $codex_home ]]; then
    echo "Codex state directory is not writable: $codex_home" >&2
    exit 1
fi

docker_args=(
    run --rm --interactive --tty
    --cap-drop ALL
    --security-opt no-new-privileges
    --security-opt "apparmor=codex-docker"
    --security-opt "seccomp=$seccomp_profile"
    --user "${codex_uid}:${codex_gid}"
    --tmpfs "/tmp:rw,exec,nosuid,nodev,size=4g,uid=${codex_uid},gid=${codex_gid},mode=1777"
    # Lake's Bubblewrap sandbox requires this target to exist under read-only /.
    --tmpfs /run/user:rw,noexec,nosuid,nodev,size=1m,mode=0755
    --mount "type=bind,src=/etc/localtime,dst=/etc/localtime,readonly"
    --mount "type=bind,src=${workspace_dir},dst=/home/codex/workspace"
    --mount "type=bind,src=${codex_home},dst=/home/codex/.codex"
    --workdir /home/codex/workspace
    --env CODEX_HOME=/home/codex/.codex
    --env UV_CACHE_DIR=/tmp/uv-cache
    # Codex tool shells may replace the image PATH, so pass the required paths
    # explicitly at container start as well.
    --env PATH=/home/codex/bin:/opt/venv/bin:/opt/elan/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin
)

# Request GPU access only when the host exposes an NVIDIA GPU.
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    docker_args+=(--gpus all)
fi

if [[ ${1:-} == bash ]]; then
    shift
    docker_args+=(--network bridge --hostname docker --entrypoint bash "$codex_image" "$@")
elif [[ ${1:-} == login ]]; then
    docker_args+=(--network host "$codex_image" "$@")
else
    docker_args+=(--network bridge --hostname docker "$codex_image" --no-daemon --sandbox danger-full-access --ask-for-approval never "$@")
fi

exec docker "${docker_args[@]}"
