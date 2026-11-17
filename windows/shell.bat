@echo off
rem  A terminal with MuScriptor's venv and settings, for `muscriptor ...`,
rem  `python`, `pytest`. `uv run` works too (UV_NO_SYNC keeps CUDA torch).
call "%~dp0env.bat"
cd /d "%MUSCRIPTOR_ROOT%"
cmd /k ""%VENV_DIR%\Scripts\activate.bat" && chcp 65001 >nul && echo MuScriptor venv: model %MUSCRIPTOR_MODEL%, %MUSCRIPTOR_DEVICE%, %MUSCRIPTOR_DTYPE%. Try: muscriptor --help"
