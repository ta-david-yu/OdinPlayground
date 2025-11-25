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

:: Grab the workspace (current directory name). We want to make a build with the name of the folder.
for %%I in ("%CD%") do set "WORKSPACE_CALLSITE=%%~nxI"

:: Build
odin build src\main.odin -file %DEBUGFLAG% -out:%OUTDIR%\%WORKSPACE_CALLSITE%.exe

:: Run. First we want to enter the exe folder to make sure the working folder is the same.
pushd "%OUTDIR%"
%WORKSPACE_CALLSITE%.exe
popd