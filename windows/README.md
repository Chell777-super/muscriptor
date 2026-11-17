# MuScriptor on Windows

One-click setup that matches `uv sync` on Linux: uv, Python from
`.python-version`, a `.venv` in the repo, every package at its `uv.lock`
version, and a CUDA build of PyTorch (the Windows wheel on PyPI is CPU-only).
Like the Docker image it also sets up the web UI, FluidSynth, MuseScore 4
and pre-downloads the soundfonts and model weights.

| Script | What it does |
|---|---|
| `install.bat` | Installs / updates everything. `--clean` rebuilds `.venv`, `--yes` skips questions. |
| `serve.bat` | Web UI on http://127.0.0.1:8222/, opens the browser when the model is loaded. |
| `transcribe.bat` | Audio to MIDI: drop files on it, or `transcribe.bat song.mp3 --format sheets`. |
| `shell.bat` | A terminal with the venv activated. |
| `env.bat` | Settings: model, dtype, port, PyTorch CUDA backends, thread counts. |

Before installing: a current NVIDIA driver, and accept the model license on
[HuggingFace](https://huggingface.co/MuScriptor) (the installer asks for a token).

Defaults are tuned for an RTX 3090 class GPU: the `large` model, `float16`
weights (CUDA already computes in fp16 via autocast; fp16 weights halve the
memory traffic of the bandwidth-bound decoding), TF32, lazy CUDA module
loading, OpenMP/MKL on the physical CPU cores. Change them in `env.bat`.

Don't run `uv sync` on Windows: it would put the CPU PyTorch from the lockfile
back. `uv run` is fine in `shell.bat` (`UV_NO_SYNC=1`); if you did sync, run
`install.bat` again.
