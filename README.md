# Codex Docker

This repository builds a standalone Codex container with access to the host's
NVIDIA GPUs. The host must have Docker, a working NVIDIA driver, and the NVIDIA
Container Toolkit configured for Docker.

Build the image from this directory:

```bash
docker build \
  --build-arg CODEX_UID="$(id -u)" \
  --build-arg CODEX_GID="$(id -g)" \
  -f Dockerfile.codex -t codex:0.154.0 .
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

The repository's `home/` directory is mounted as `/home/codex`, providing
container-wide tools and instructions. Persistent Codex state is stored
separately in `~/.codex-docker/` and mounted at `/home/codex/.codex`; it
includes `config.toml`, login credentials, history, logs, and caches. To
authenticate for the first time, run `run-codex --bash -lc 'codex login'`.

The container runs as the invoking host user, mounts the current directory,
uses Docker bridge networking, and requests GPU access when an NVIDIA GPU is
available. It does not mount the host's Docker socket or SSH credentials.

The x86-64 binaries, unpinned dependencies, unrestricted Codex sandbox, and
GPU access when available are intentional; the launcher automatically omits
GPU access on hosts where `nvidia-smi` cannot detect an NVIDIA GPU.

## Lean verification

The image includes pinned Lean 4, Lake, and a cached Mathlib checkout. Use
`lean` for core Lean files and `lean-mathlib.sh` for standalone files that
import Mathlib:

```bash
lean Proof.lean
lean-mathlib.sh ProofWithMathlib.lean
```

For a Lean project, use its normal commands such as `lake build`. A project
`lean-toolchain` file selects its own Lean version, and project dependencies
remain managed by its `lakefile`.

The image defaults can be updated deliberately at build time with
`ELAN_VERSION`, `LEAN_TOOLCHAIN`, and `MATHLIB_REF` build arguments. The Lean
toolchain and Mathlib reference must remain compatible.
