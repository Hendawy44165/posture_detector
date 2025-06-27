import os
import sys
import subprocess

VENV_DIR = os.path.join(os.path.dirname(__file__), "venv")
REQUIREMENTS = os.path.join(os.path.dirname(__file__), "requirements.txt")

if not os.path.exists(VENV_DIR):
    print("Creating virtual environment...")
    subprocess.check_call([sys.executable, "-m", "venv", VENV_DIR])

pip_path = (
    os.path.join(VENV_DIR, "bin", "pip") if os.name != "nt" else os.path.join(VENV_DIR, "Scripts", "pip.exe")
)

print("Installing requirements...")
subprocess.check_call([pip_path, "install", "-r", REQUIREMENTS])
