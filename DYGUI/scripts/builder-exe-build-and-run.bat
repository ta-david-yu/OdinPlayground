@echo off
setlocal

:: Check if an argument was provided for the run parameter
if "%~1"=="" (
    set "DEBUGFLAG="
) else (
    if /i "%~1"=="debug" (
        set "DEBUGFLAG=debug"
    ) else (
        set "DEBUGFLAG="
    )
)

if not exist "build\tools" mkdir "build\tools"
set "OUT=build\tools\builder.exe"

:: Build
odin build dll-builder\builder.odin -file -out:%OUT%

:: Run
%OUT% %DEBUGFLAG%
