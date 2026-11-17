@echo off
rem  Audio to MIDI on the GPU. Drop audio files onto this script, or:
rem    transcribe.bat song.mp3 [more files ...]
rem    transcribe.bat song.mp3 --format sheets --quantize    (options after the file)
rem  With options, the first argument is the file and the rest go to
rem  `muscriptor transcribe` as-is. Output lands next to the audio file.
setlocal EnableExtensions
chcp 65001 >nul
title MuScriptor transcribe
call "%~dp0env.bat"
if not exist "%VENV_DIR%\Scripts\muscriptor.exe" (
    echo MuScriptor is not installed yet: run windows\install.bat first.
    pause
    exit /b 1
)
set "MS=%VENV_DIR%\Scripts\muscriptor.exe"
set "COMMON=--model %MUSCRIPTOR_MODEL% --device %MUSCRIPTOR_DEVICE% --dtype %MUSCRIPTOR_DTYPE%"

if "%~1"=="" (
    "%MS%" transcribe --help
    pause
    exit /b 0
)

rem  Options given: one file plus pass-through options.
set "ARG2=%~2"
if defined ARG2 if "%ARG2:~0,1%"=="-" (
    "%MS%" transcribe %COMMON% %*
    goto :end
)

rem  Otherwise: a list of files (drag and drop).
:next_file
if "%~1"=="" goto :end
echo.
echo === %~nx1
"%MS%" transcribe %COMMON% "%~f1"
shift
goto :next_file

:end
endlocal
pause
