# Available tools

Vampire, LaTeX, CaDiCaL, Python, Torch, Tesseract OCR, and Lean are installed.
Python and pip use /opt/venv; PyTorch includes CUDA support.
Lean v4.35.0 includes Comparator and leanexport; Bubblewrap is installed.
Use `lake comparator --config config.json` to compare a proof with a challenge,
or `lake check` to check a project. Both require a compatible project toolchain,
a lake-manifest.json, and host support for Bubblewrap namespaces.
Use `lean-mathlib.sh` for standalone Lean files that import Mathlib.
If you are missing ANY tool that would make your work easier, then
report it to the user!
