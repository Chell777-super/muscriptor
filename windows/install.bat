@echo off
rem ==========================================================================
rem  MuScriptor - Windows installer: uv + venv + CUDA PyTorch.
rem
rem  Gives the same setup as `uv sync` on Linux: Python from .python-version,
rem  a .venv in the repo, every package at its uv.lock version - except
rem  PyTorch, whose Windows wheel on PyPI is CPU-only, so the CUDA build is
rem  taken from the PyTorch index instead. Plus what the Docker image has:
rem  the web UI, FluidSynth, MuseScore 4 and the pre-downloaded soundfonts.
rem
rem  Usage:  windows\install.bat [--clean] [--yes]
rem    --clean   delete .venv and start over
rem    --yes     do not ask, install the optional parts too
rem  Safe to re-run: finished steps are skipped or quick.
rem ==========================================================================
setlocal EnableExtensions
chcp 65001 >nul
title MuScriptor - Windows installer

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%env.bat"
cd /d "%MUSCRIPTOR_ROOT%"
if not exist "pyproject.toml" (
    echo [x] pyproject.toml not found in "%MUSCRIPTOR_ROOT%".
    echo     Keep this script in the windows folder of the muscriptor repository.
    goto :fail
)

set "OPT_CLEAN="
set "OPT_YES="
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--clean" set "OPT_CLEAN=1"
if /i "%~1"=="--yes" set "OPT_YES=1"
shift
goto :parse_args
:args_done

set "BUILD_DIR=%SCRIPT_DIR%.build"
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

rem --------------------------------------------------------------------------
echo.
echo [1/8] uv
where uv >nul 2>&1
if not errorlevel 1 goto :uv_ok
echo     uv not found, installing it from astral.sh ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
where uv >nul 2>&1
if errorlevel 1 (
    echo [x] uv is still not on PATH. Open a new terminal and run this script again.
    goto :fail
)
:uv_ok
for /f "delims=" %%v in ('uv --version') do echo     %%v

rem --------------------------------------------------------------------------
echo.
echo [2/8] NVIDIA GPU
where nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo [!] nvidia-smi not found: install a current NVIDIA Game Ready / Studio driver first.
) else (
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
)

rem --------------------------------------------------------------------------
echo.
echo [3/8] Python and .venv
set "PY_VER="
for /f "usebackq delims=" %%v in (".python-version") do if not defined PY_VER set "PY_VER=%%v"
if not defined PY_VER set "PY_VER=3.13"
if defined OPT_CLEAN if exist "%VENV_DIR%" (
    echo     --clean: removing .venv
    rmdir /s /q "%VENV_DIR%"
)
uv python install %PY_VER%
if errorlevel 1 goto :fail
if not exist "%VENV_PY%" (
    uv venv "%VENV_DIR%" --python %PY_VER%
    if errorlevel 1 goto :fail
)
"%VENV_PY%" --version

rem --------------------------------------------------------------------------
echo.
echo [4/8] Dependencies from uv.lock + CUDA PyTorch
rem  The lockfile pins, minus torch/torchaudio, which come from the CUDA index.
uv export --frozen --no-hashes --no-header --no-annotate --no-emit-project -o "%BUILD_DIR%\requirements-lock.txt" >nul
if errorlevel 1 goto :fail
findstr /V /R /C:"^torch==" /C:"^torchaudio==" "%BUILD_DIR%\requirements-lock.txt" > "%BUILD_DIR%\requirements.txt"

set "TORCH_OK="
for %%B in (%MUSCRIPTOR_TORCH_BACKENDS%) do if not defined TORCH_OK call :install_deps %%B
if not defined TORCH_OK (
    echo [x] Could not get a working CUDA PyTorch with any of: %MUSCRIPTOR_TORCH_BACKENDS%
    echo     Update the NVIDIA driver, then run this script again.
    goto :fail
)
echo     using PyTorch backend %TORCH_OK%

rem --------------------------------------------------------------------------
echo.
echo [5/8] Web UI
if exist "muscriptor\web_dist\index.html" (
    echo     already built
    goto :webui_done
)
where pnpm >nul 2>&1
if errorlevel 1 goto :webui_download
echo     building with pnpm ...
pushd web
call pnpm install --frozen-lockfile && call pnpm run build
popd
if exist "muscriptor\web_dist\index.html" goto :webui_done
:webui_download
echo     taking the prebuilt UI from the PyPI wheel ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%fetch.ps1" -Root "%MUSCRIPTOR_ROOT%" -What webui
if errorlevel 1 echo [!] No web UI: `serve` still works as an API. Install pnpm and re-run to build it.
:webui_done

rem --------------------------------------------------------------------------
echo.
echo [6/8] FluidSynth (MIDI to audio: --auralize and /auralize)
where fluidsynth >nul 2>&1
if not errorlevel 1 (
    echo     found on PATH
    goto :fluidsynth_done
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%fetch.ps1" -Root "%MUSCRIPTOR_ROOT%" -What fluidsynth
if errorlevel 1 echo [!] FluidSynth not installed: everything except auralization still works.
:fluidsynth_done

rem --------------------------------------------------------------------------
echo.
echo [7/8] MuseScore 4 (sheet music: --format sheets and the PDF download)
if defined MUSCRIPTOR_MUSESCORE (
    echo     %MUSCRIPTOR_MUSESCORE%
    goto :musescore_done
)
where winget >nul 2>&1
if errorlevel 1 (
    echo [!] Not found and winget is missing: get it from https://musescore.org/en/download
    goto :musescore_done
)
if defined OPT_YES goto :musescore_install
choice /c YN /m "    MuseScore 4 not found. Install it with winget"
if errorlevel 2 goto :musescore_done
:musescore_install
winget install -e --id MuseScore.MuseScore --accept-package-agreements --accept-source-agreements
call "%SCRIPT_DIR%env.bat"
if defined MUSCRIPTOR_MUSESCORE (echo     %MUSCRIPTOR_MUSESCORE%) else (echo [!] MuseScore still not found; set MUSCRIPTOR_MUSESCORE to MuseScore4.exe)
:musescore_done

rem --------------------------------------------------------------------------
echo.
echo [8/8] HuggingFace login, weights, test run
"%VENV_PY%" -c "import sys; from huggingface_hub import get_token; sys.exit(0 if get_token() else 1)"
if not errorlevel 1 goto :hf_ok
echo     The weights are gated (CC BY-NC 4.0). First accept the license here:
echo       https://huggingface.co/MuScriptor/muscriptor-%MUSCRIPTOR_MODEL%
echo     then paste a read token from https://huggingface.co/settings/tokens
"%VENV_DIR%\Scripts\hf.exe" auth login
:hf_ok
"%VENV_PY%" "%SCRIPT_DIR%prefetch.py"
if errorlevel 1 (
    echo [!] Prefetch failed - see above. Fix it and re-run, or the download happens on first use.
)

echo.
echo ==========================================================================
echo  Done. PyTorch: %TORCH_OK%, model: %MUSCRIPTOR_MODEL%, dtype: %MUSCRIPTOR_DTYPE%
echo.
echo    windows\serve.bat           web UI at http://127.0.0.1:%MUSCRIPTOR_PORT%/
echo    windows\transcribe.bat FILE  audio to MIDI (or drop files on it)
echo    windows\shell.bat           terminal with the venv activated
echo.
echo  Settings: windows\env.bat. Do not use `uv sync` on Windows: it would
echo  replace the CUDA PyTorch with the CPU one (re-run this script if you did).
echo ==========================================================================
endlocal
pause
exit /b 0

:fail
echo.
echo [x] Installation failed.
endlocal
pause
exit /b 1

rem --------------------------------------------------------------------------
rem  :install_deps BACKEND - install the locked deps with PyTorch from BACKEND
rem  (cu130, cu128, ...) and keep it only if it really runs on the GPU.
:install_deps
echo.
echo     --- PyTorch %1 ---
uv pip install --python "%VENV_PY%" --torch-backend=%1 ^
    --reinstall-package torch --reinstall-package torchaudio ^
    -r "%BUILD_DIR%\requirements.txt" -e "%MUSCRIPTOR_ROOT%"
if errorlevel 1 (
    echo [!] install with %1 failed
    exit /b 0
)
"%VENV_PY%" "%SCRIPT_DIR%check_gpu.py"
if errorlevel 1 exit /b 0
set "TORCH_OK=%1"
exit /b 0
