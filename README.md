# Codex Docker

This repository builds a standalone Codex container with access to the host's
NVIDIA GPUs. The host must have Docker, a working NVIDIA driver, and the NVIDIA
Container Toolkit configured for Docker.

Build and authenticate from this directory:

```bash
./build-image.sh
./run-codex.sh login
```

Add the launcher to `PATH` and run it from your project directory:

```bash
ln -s "$PWD/run-codex.sh" "$HOME/.local/bin/run-codex.sh"
cd /path/to/project
run-codex.sh
```

Use `run-codex.sh bash` for a shell. Additional arguments are passed to
Codex, Bash, or `codex login`, depending on the mode.

The current directory is mounted at `/home/codex/workspace`, and persistent
Codex state (including credentials) at `~/.codex-docker/`, mounted as
`/home/codex/.codex`.

The container runs as the invoking host user, mounts the current directory,
uses Docker bridge networking (host networking for `login`), and requests GPU
access when an NVIDIA GPU is available. It does not mount the host's Docker
socket or SSH credentials.

The x86-64 binaries, unpinned dependencies, unrestricted Codex sandbox, and
GPU access when available are intentional; the launcher automatically omits
GPU access on hosts where `nvidia-smi` cannot detect an NVIDIA GPU.

## Lean verification

The image includes pinned Lean 4, Lake, and cached Mathlib:

```bash
lean Proof.lean
lean-mathlib.sh ProofWithMathlib.lean
```

For Lean projects, use `lake build`; `lean-toolchain` and `lakefile` select
the project's toolchain and dependencies.

Build arguments `ELAN_VERSION`, `LEAN_TOOLCHAIN`, and `MATHLIB_REF` override
the image defaults. Keep the Lean toolchain and Mathlib reference compatible.
