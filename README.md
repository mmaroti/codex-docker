# Codex with CUDA

The host requires Docker, a working NVIDIA driver, and NVIDIA Container
Toolkit configured for Docker. Run these checks outside Codex's sandbox:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:13.0.2-base-ubuntu24.04 nvidia-smi
```

Build the image from the repository root:

```bash
docker build \
  --build-arg CODEX_UID="$(id -u)" \
  --build-arg CODEX_GID="$(id -g)" \
  -f Dockerfile.codex -t codex:0.149.0 .
```

Check that PyTorch sees only GPU 0:

```bash
docker run --rm --gpus device=0 --entrypoint python codex:0.149.0 -c \
  'import torch; assert torch.cuda.is_available(); assert torch.cuda.current_device() == 0'
```

Log in with ChatGPT on the host, then start Codex:

```bash
codex login
./run-codex.sh
```

To open Bash in the same environment instead, run:

```bash
./run-codex.sh --bash
```

The launcher runs as non-root `codex`, using the `CODEX_UID` and `CODEX_GID`
build arguments. The documented values match the invoking host user. It
bind-mounts this repository and the host Codex `auth.json`, provides GPU 0, uses
Docker bridge networking, and keeps `CODEX_HOME` on tmpfs except for that
read-only authentication file. It does not mount host Codex configuration, SSH
credentials, or the Docker socket.

The launcher requires the host `~/.codex/auth.json`, created by `codex login`.
It mounts that file read-only, so the container can use the host's ChatGPT
authentication but cannot update it. If the credential needs a refresh, update
it by running `codex login` on the host. History, logs, plugins, caches, and all
other Codex-generated files remain in tmpfs and disappear when the container
exits.

The persistent container configuration is
[`docker/codex/config.toml`](docker/codex/config.toml). It sets the model,
reasoning effort, status line, and trust for `/home/codex/relator`. Codex uses a
symbolic link to this file, so settings changed through Codex are written to the
repository immediately. Edit it on the host or through Codex; host-side edits
are used on the next launch. Keep this file free of API keys, MCP secrets, and
other credentials.

The repository bind mount hides the image's path at `/home/codex/relator`.
Therefore the host `.git` directory is available inside the container and all
Git operations affect the host repository. The host `.venv` is also visible,
but the container sets `UV_PROJECT_ENVIRONMENT=/opt/venv`, so `uv` uses the
image's isolated environment instead.
