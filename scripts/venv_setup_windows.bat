@echo off
REM Create virtual environment in .\venv if it does not exist
if not exist venv (
    python -m venv venv
)

REM Activate the virtual environment
call venv\Scripts\activate.bat

REM Upgrade pip
python -m pip install --upgrade pip

REM Install requirements
if exist requirements.txt (
    pip install -r requirements.txt
) else (
    echo requirements.txt not found!
    exit /b 1
)
