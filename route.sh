#!/bin/bash
set -e


echo "▶ Cleaning up existing processes and locks..."
pkill -9 -f "python app.py" 2>/dev/null || true
pkill -9 -f "chromium" 2>/dev/null || true
pkill -9 -f "chrome" 2>/dev/null || true
rm -f /tmp/.X99-lock


trap 'echo "▶ Shutting down..."; pkill -P $$ 2>/dev/null || true; exit 0' SIGTERM SIGINT


REPO=$(echo "$API_URL" | cut -d '=' -f1)
SERVICE=$(echo "$API_URL" | cut -d '=' -f4)
echo "▶ Deploying: $SERVICE"

cd /app && rm -rf repo
git clone --depth=1 "$REPO" repo && cd "repo/$SERVICE" || exit 1


echo "▶ Setting up Chromium environment..."
mkdir -p /tmp/chromium-home/.config
mkdir -p /tmp/chromium-home/.cache

export HOME=/tmp/chromium-home
export XDG_CONFIG_HOME=/tmp/chromium-home/.config
export XDG_CACHE_HOME=/tmp/chromium-home/.cache
export CHROME_BIN=/usr/bin/chromium
export DEBUG=${DEBUG:-false}
export HEADLESS=${HEADLESS:-false}


echo "▶ Starting Xvfb display :99..."
Xvfb :99 -screen 0 1024x768x24 +extension GLX +render >/dev/null 2>&1 &
export DISPLAY=:99
sleep 1


echo "▶ Setting up Python VENV..."
python3 -m venv venv && source venv/bin/activate
pip install --upgrade pip -q
pip install . -q

echo "▶ Starting Uvicorn on port ${PORT:-7860}..."
exec uvicorn app:app --host 0.0.0.0 --port ${PORT:-7860}