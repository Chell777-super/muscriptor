@echo off
rem ==========================================================================
rem  MuScriptor on Windows - shared settings, sourced by the other scripts.
rem  Tuned for: RTX 3090 (24 GB, Ampere sm_86), i5-11400F (6C/12T), 16 GB RAM.
rem  Any variable below can be overridden by setting it before calling.
rem ==========================================================================

for %%I in ("%~dp0..") do set "MUSCRIPTOR_ROOT=%%~fI"
set "VENV_DIR=%MUSCRIPTOR_ROOT%\.venv"
set "VENV_PY=%VENV_DIR%\Scripts\python.exe"
set "TOOLS_DIR=%MUSCRIPTOR_ROOT%\windows\tools"

rem ---- What to run ---------------------------------------------------------
rem  large = most accurate (1.4B), easily fits in 24 GB. small / medium are faster.
if not defined MUSCRIPTOR_MODEL set "MUSCRIPTOR_MODEL=large"
rem  float16 weights: CUDA already computes in fp16 via autocast, so storing the
rem  weights in fp16 halves VRAM traffic (decoding is bandwidth-bound) and skips
rem  the per-op casts. Set to float32 to get the stock behaviour back.
if not defined MUSCRIPTOR_DTYPE set "MUSCRIPTOR_DTYPE=float16"
if not defined MUSCRIPTOR_DEVICE set "MUSCRIPTOR_DEVICE=cuda"
if not defined MUSCRIPTOR_HOST set "MUSCRIPTOR_HOST=127.0.0.1"
if not defined MUSCRIPTOR_PORT set "MUSCRIPTOR_PORT=8222"
if not defined MUSCRIPTOR_OPEN_BROWSER set "MUSCRIPTOR_OPEN_BROWSER=1"
rem  CUDA builds of PyTorch tried by install.bat, in order. cu130 is what Linux
rem  gets from PyPI; the older ones are fallbacks for older NVIDIA drivers.
if not defined MUSCRIPTOR_TORCH_BACKENDS set "MUSCRIPTOR_TORCH_BACKENDS=cu130 cu128 cu126"

rem ---- Runtime optimizations ----------------------------------------------
rem  UTF-8 everywhere: the CLI prints characters a cp1251/cp866 console chokes on.
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
rem  CPU work (audio decoding, mel spectrogram, beat tracking) on the 6
rem  physical cores; hyper-threads only add contention for OpenMP/MKL.
if not defined OMP_NUM_THREADS set "OMP_NUM_THREADS=6"
if not defined MKL_NUM_THREADS set "MKL_NUM_THREADS=6"
rem  Load CUDA kernels on first use: faster start, less RAM/VRAM.
set "CUDA_MODULE_LOADING=LAZY"
rem  Ampere TensorFloat-32 for any matmul still done in fp32.
set "TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1"
rem  HuggingFace: quiet on Windows, faster parallel downloads of the weights.
set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"
set "HF_HUB_DISABLE_TELEMETRY=1"
set "HF_XET_HIGH_PERFORMANCE=1"

rem ---- uv ------------------------------------------------------------------
set "UV_PROJECT_ENVIRONMENT=%VENV_DIR%"
set "UV_LINK_MODE=copy"
set "UV_COMPILE_BYTECODE=1"
rem  `uv run` / `uv sync` would re-sync the lockfile, whose Windows torch is the
rem  CPU-only PyPI build, and silently drop the CUDA one. Never auto-sync here.
set "UV_NO_SYNC=1"

rem ---- PATH: uv, FluidSynth (for /auralize and --auralize) -----------------
if defined MUSCRIPTOR_PATH_SET goto :path_done
set "MUSCRIPTOR_PATH_SET=1"
set "PATH=%USERPROFILE%\.local\bin;%TOOLS_DIR%\fluidsynth\bin;%PATH%"
:path_done

rem ---- MuseScore 4 (for --format sheets and the sheet music download) ------
if defined MUSCRIPTOR_MUSESCORE goto :musescore_done
for %%M in ("%ProgramFiles%\MuseScore 4\bin\MuseScore4.exe" "%LOCALAPPDATA%\Programs\MuseScore 4\bin\MuseScore4.exe") do (
    if not defined MUSCRIPTOR_MUSESCORE if exist "%%~M" set "MUSCRIPTOR_MUSESCORE=%%~M"
)
:musescore_done
exit /b 0
