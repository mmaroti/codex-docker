#!/usr/bin/env bash
set -euo pipefail

if (($# != 0)); then
  echo "Usage: $0" >&2
  exit 2
fi

builder_path=$(readlink -f -- "${BASH_SOURCE[0]}")
builder_dir=$(dirname -- "$builder_path")

exec docker build \
  --build-arg CODEX_UID="$(id -u)" \
  --build-arg CODEX_GID="$(id -g)" \
  -f "$builder_dir/Dockerfile.codex" -t codex:0.166.0 "$builder_dir"
