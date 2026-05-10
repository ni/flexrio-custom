@echo off
REM ============================================================
REM nisetup.bat - Set up Python venv for this workspace
REM
REM Creates the venv (if needed), installs packages, and
REM activates the environment in the caller's shell.
REM ============================================================

call python "%~dp0nisetup.py" "%~dp0."
if not %errorlevel%==0 (
    echo nisetup.py failed.
    exit /b 1
)

echo.
echo Activating virtual environment...
call "%~dp0.venv\Scripts\activate.bat"
