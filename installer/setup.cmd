@echo off
rem Runs once at install time (called by the installer). Mirrors the Dockerfile:
rem   locked deps -> bytecode compiled -> soundfonts prefetched.
setlocal
set "APP=%~dp0"
cd /d "%APP%"

rem Everything lives under the install dir so uninstalling removes it all.
set "UV_PYTHON_INSTALL_DIR=%APP%python"
set "UV_CACHE_DIR=%APP%uv-cache"
set "UV_LINK_MODE=copy"
set "UV_COMPILE_BYTECODE=1"
set "HF_HUB_CACHE=%APP%hf-cache"
set "PY=%APP%venv\Scripts\python.exe"

echo.
echo [1/4] Installing Python 3.13 ...
"%APP%bin\uv.exe" venv --python 3.13 --managed-python "%APP%venv" || goto :fail

echo.
echo [2/4] Installing locked dependencies (PyTorch is large, this takes a while) ...
rem --torch-backend=auto picks the CUDA build when an NVIDIA driver is found and
rem the CPU build otherwise; the exact versions come from uv.lock.
"%APP%bin\uv.exe" pip install --python "%PY%" --torch-backend=auto --compile-bytecode -r "%APP%requirements.txt" || goto :fail

echo.
echo [3/4] Installing MuScriptor ...
for %%f in ("%APP%wheel\*.whl") do set "WHEEL=%%~f"
"%APP%bin\uv.exe" pip install --python "%PY%" --no-deps --compile-bytecode "%WHEEL%" || goto :fail

echo.
echo [4/4] Downloading soundfonts (253 MB) ...
"%PY%" -I "%APP%prewarm.py" || goto :fail

rem The uv cache only duplicates what is now in venv (several GB).
rd /s /q "%APP%uv-cache" 2>nul
echo.
echo Done.
exit /b 0

:fail
echo.
echo Setup failed. Check your internet connection and run setup again.
exit /b 1
