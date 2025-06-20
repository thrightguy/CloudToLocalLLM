@echo off
REM CloudToLocalLLM Batch Wrapper
REM Launches the CloudToLocalLLM application

set SCRIPT_DIR=%~dp0
set EXE_PATH=%SCRIPT_DIR%bin\cloudtolocalllm.exe

if exist "%EXE_PATH%" (
    "%EXE_PATH%" %*
) else (
    echo CloudToLocalLLM executable not found at %EXE_PATH%
    exit /b 1
)
