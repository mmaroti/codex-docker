# Codex Docker

Requires Docker on an x86-64 Linux host. GPU access additionally requires an
NVIDIA driver and NVIDIA Container Toolkit; the launcher enables it when a GPU
is detected.

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

The launcher mounts your project at `/home/codex/workspace`, this repository's
`home/` directory at `/home/codex`, and persistent credentials and Codex state
from `~/.codex-docker/`. It runs as your host user with unrestricted Codex
sandbox access inside the container.

Tools include Python, PyTorch with CUDA, uv, Lean, Lake, Mathlib,
Comparator, Vampire, CaDiCaL, LaTeX, and OCR. In a container shell:

```bash
python script.py
lean Proof.lean
lean-mathlib.sh ProofWithMathlib.lean
lake build
lake env comparator config.json
```

Lean, Mathlib, Comparator, and lean4export must use matching Lean versions.
Nanoda is not installed. Comparator requires host Landlock support and Docker
permission for its syscalls.
