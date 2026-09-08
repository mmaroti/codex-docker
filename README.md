# Codex Docker

This repository builds a standalone Codex container with access to the host's
NVIDIA GPUs. The host must have Docker, a working NVIDIA driver, and the NVIDIA
Container Toolkit configured for Docker.

Build the image from this directory:

```bash
docker build \
  --build-arg CODEX_UID="$(id -u)" \
  --build-arg CODEX_GID="$(id -g)" \
  -f Dockerfile.codex -t codex:0.153.0 .
```

Run the launcher from any directory. That directory is mounted at
`/home/codex/workspace` in the container, so a symlink to `run-codex.sh` can be
placed anywhere on `PATH`:

```bash
ln -s "$PWD/run-codex.sh" "$HOME/.local/bin/run-codex"
cd /path/to/project
run-codex
```

Use `run-codex --bash` to open a shell in the same container. Additional
arguments are passed to Codex.

Codex state is stored persistently in `~/.codex-docker/`, independent of the
directory from which the launcher is run. This includes `config.toml`, login
credentials, history, logs, and caches. To authenticate for the first time,
run `run-codex --bash -lc 'codex login'`.

The container runs as the invoking host user, mounts the current directory,
uses Docker bridge networking, and requests GPU access when an NVIDIA GPU is
available. It does not mount the host's Docker socket or SSH credentials.

The x86-64 binaries, unpinned dependencies, unrestricted Codex sandbox, and
GPU access when available are intentional; the launcher automatically omits
GPU access on hosts where `nvidia-smi` cannot detect an NVIDIA GPU.
