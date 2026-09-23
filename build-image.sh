#!/usr/bin/env bash

docker build \
  --build-arg CODEX_UID="$(id -u)" \
  --build-arg CODEX_GID="$(id -g)" \
  -f Dockerfile.codex -t codex:0.156.0 .
