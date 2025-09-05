@echo off
setlocal

:: Check if an argument was provided for subfolder
if "%~1"=="" (
    set "OUTDIR=build"
    set "DEBUGFLAG="
) else (
    set "OUTDIR=build\%~1"
    if /i "%~1"=="debug" (
        set "DEBUGFLAG=-debug"
    ) else (
        set "DEBUGFLAG="
    )
)

:: Ensure the directory exists
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

:: Run the build
odin build src\game\game.odin -file %DEBUGFLAG% -build-mode:dll -out:"%OUTDIR%\game.dll"