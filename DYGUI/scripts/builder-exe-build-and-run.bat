@echo off
setlocal

set "OUT=build\builder.exe"

:: Build
odin build dll-builder\builder.odin -file -out:%OUT%

:: Run
%OUT%