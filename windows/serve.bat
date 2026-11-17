@echo off
rem  MuScriptor web UI + API on the GPU. Extra arguments go to `muscriptor serve`,
rem  e.g.  serve.bat --model medium   or   serve.bat --host 0.0.0.0
setlocal EnableExtensions
chcp 65001 >nul
title MuScriptor server
call "%~dp0env.bat"
if not exist "%VENV_DIR%\Scripts\muscriptor.exe" (
    echo MuScriptor is not installed yet: run windows\install.bat first.
    pause
    exit /b 1
)
cd /d "%MUSCRIPTOR_ROOT%"

set "OPEN_HOST=%MUSCRIPTOR_HOST%"
if "%OPEN_HOST%"=="0.0.0.0" set "OPEN_HOST=127.0.0.1"
set "URL=http://%OPEN_HOST%:%MUSCRIPTOR_PORT%/"
rem  Open the browser once the server answers (the model takes a while to load).
if "%MUSCRIPTOR_OPEN_BROWSER%"=="1" start "" /b powershell -NoProfile -Command "for ($i = 0; $i -lt 900; $i++) { try { Invoke-WebRequest '%URL%' -UseBasicParsing -TimeoutSec 2 | Out-Null; Start-Process '%URL%'; break } catch { Start-Sleep 1 } }"

echo Model %MUSCRIPTOR_MODEL%, %MUSCRIPTOR_DEVICE%, %MUSCRIPTOR_DTYPE% - %URL%  (Ctrl+C to stop)
"%VENV_DIR%\Scripts\muscriptor.exe" serve --host %MUSCRIPTOR_HOST% --port %MUSCRIPTOR_PORT% --model %MUSCRIPTOR_MODEL% --device %MUSCRIPTOR_DEVICE% --dtype %MUSCRIPTOR_DTYPE% %*
endlocal
pause
