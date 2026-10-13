#!/bin/bash
set -e

export PORT="${PORT:-7860}"

echo "Cleaning up existing processes and locks..."
pkill -9 -f "node" 2>/dev/null || true
pkill -9 -f "python" 2>/dev/null || true
pkill -9 -f "chromium" 2>/dev/null || true
pkill -9 -f "chrome" 2>/dev/null || true
rm -f /tmp/.X99-lock

SERVICE="$(basename "$PWD")"
echo "Deploying: $SERVICE on PORT: $PORT"

if [ -f ".needs-browser" ]; then
    echo "Setting up Chromium & Xvfb..."
    mkdir -p /tmp/chromium-home/.config /tmp/chromium-home/.cache
    export HOME=/tmp/chromium-home
    export XDG_CONFIG_HOME=/tmp/chromium-home/.config
    export XDG_CACHE_HOME=/tmp/chromium-home/.cache
    export CHROME_BIN=/usr/bin/chromium
    export HEADLESS=false
    Xvfb :99 -screen 0 1024x768x24 +extension GLX +render >/dev/null 2>&1 &
    export DISPLAY=:99
    sleep 1
else
    echo "No browser needed."
fi

if [ -f "package.json" ]; then
    if [ -f "package-lock.json" ]; then npm ci --omit=dev --quiet
    else npm install --omit=dev --quiet; fi
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
    python3 -m venv venv && source venv/bin/activate
    pip install --upgrade pip -q
    if [ -f "pyproject.toml" ]; then pip install . -q
    elif [ -f "requirements.txt" ]; then pip install -r requirements.txt -q; fi
else
    echo "Error: No recognizable project type."
    exit 1
fi

set +e

while true; do
    echo ">>> Starting app..."
    
    if [ -f "package.json" ]; then
        node app.js &
    else
        source venv/bin/activate
        if [ -f "app.py" ] && command -v uvicorn &> /dev/null; then
            uvicorn app:app --host 0.0.0.0 --port "$PORT" &
        else
            python app.py &
        fi
    fi
    
    APP_PID=$!
    wait $APP_PID
    EXIT_CODE=$?
    
    echo ">>> App exited with code $EXIT_CODE. Restarting in 3s..."
    sleep 3
done