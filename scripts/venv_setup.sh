#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Create virtual environment in ./venv if it does not exist
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Activate the virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install requirements
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "requirements.txt not found!"
    exit 1
fi
