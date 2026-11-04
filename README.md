# Codex Docker

Requires an x86-64 machine with Docker running Linux containers. Run the Bash
scripts on Linux or in an Ubuntu WSL 2 terminal on Windows. Native PowerShell
and Windows containers are not supported.

On Windows, install Docker Desktop with the WSL 2 backend and enable integration
with your Ubuntu distribution. Clone this repository and your projects into the
WSL Linux filesystem (for example, `~/projects`), rather than `/mnt/c`, for better
filesystem performance and Unix permissions. Enable host networking in Docker
Desktop's Settings > Resources > Network for the login command below.

GPU access is optional. On Linux it requires an NVIDIA driver and NVIDIA
Container Toolkit. On Windows it requires a compatible NVIDIA Windows driver
and Docker Desktop's WSL 2 backend. The launcher requests GPU access when
`nvidia-smi` is available and detects a GPU.

Build and authenticate from this directory:

```bash
./build-image.sh
./run-codex.sh login
```

Add the launcher to `PATH`, then run it from your project directory:

```bash
mkdir -p "$HOME/.local/bin"
ln -s "$PWD/run-codex.sh" "$HOME/.local/bin/run-codex.sh"
cd /path/to/project
run-codex.sh
```

Use `run-codex.sh bash` for a shell. Additional arguments are passed to the
selected command.

The launcher mounts your project at `/home/codex/workspace` and persistent
credentials and Codex state from `~/.codex-docker/` at `/home/codex/.codex`.
Each container has its own writable home directory, seeded at image build time
with all files from this repository's `home/` directory except `.codex/`.
Files added there, including dotfiles and files not yet tracked by Git, appear
in new containers after rebuilding with `./build-image.sh`. Other home directory
changes are discarded when the container is removed.
It runs as your host user with unrestricted Codex sandbox access inside the
container. Docker's default AppArmor/seccomp policies apply where supported;
no custom host security profiles are required. The launcher also drops all
capabilities and enables `no-new-privileges`. Containers use their default
timezone rather than mounting the host's `/etc/localtime`.
Interactive Codex launches use `--no-daemon`, so you can manage
independent instances with tmux.

Tools include Python, PyTorch with CUDA, uv, Lean, Lake, Mathlib,
Comparator, Vampire, CaDiCaL, LaTeX, and OCR. In a container shell:

```bash
python script.py
lean Proof.lean
lean-mathlib.sh ProofWithMathlib.lean
lake build
```

Lean and Mathlib are pinned to v4.35.0. Comparator and the matching `leanexport`
are included in the Lean toolchain, but `lake comparator` and `lake check` depend
on a nested Bubblewrap sandbox that may be blocked by Docker's default security
settings. These commands are not part of the supported container workflow.
