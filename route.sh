#!/bin/bash

set -e

cleanup() {
    echo "──────────────────────────────────────────"
    echo "SHUTTING DOWN: Cleaning up processes..."
    echo "──────────────────────────────────────────"
    fuser -k 99/tcp 2>/dev/null || true
    pkill -P $$ 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

REPO=$(echo "$API_URL" | cut -d '=' -f1)
SERVICE=$(echo "$API_URL" | cut -d '=' -f4)

echo "──────────────────────────────────────────"
echo "DEPLOYER STARTING: $SERVICE"
echo "──────────────────────────────────────────"

cd /app || exit 1
rm -rf repo
git clone --depth=1 "$REPO" repo || { echo "Git clone failed"; exit 1; }
cd "repo/$SERVICE" || { echo "Folder $SERVICE not found"; exit 1; }

rm -f /tmp/.X99-lock

echo "Starting Xvfb display :99..."
Xvfb :99 -screen 0 1024x768x24 -ac -noreset +extension GLX +render > /dev/null 2>&1 &
export DISPLAY=:99

sleep 2

echo "Python detected. Setting up VENV..."
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install .

echo "──────────────────────────────────────────"
echo "Detecting Framework..."
echo "──────────────────────────────────────────"

if grep -qiE "fastapi|uvicorn" pyproject.toml 2>/dev/null; then
    echo "FastAPI/Uvicorn project."
    exec uvicorn app:app --host 0.0.0.0 --port ${PORT:-7860}
else
    echo "Flask/Standard Python project."
    exec python app.py
fi