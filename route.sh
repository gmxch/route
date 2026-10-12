#!/bin/bash
set -e

echo "Cleaning up existing processes and locks..."
pkill -9 -f "node" 2>/dev/null || true
pkill -9 -f "python" 2>/dev/null || true
pkill -9 -f "chromium" 2>/dev/null || true
pkill -9 -f "chrome" 2>/dev/null || true
rm -f /tmp/.X99-lock

trap 'echo "Shutting down..."; pkill -P $$ 2>/dev/null || true; exit 0' SIGTERM SIGINT

REPO=$(echo "$API_URL" | cut -d '=' -f1)
SERVICE=$(echo "$API_URL" | cut -d '=' -f4)
echo "Target Service: $SERVICE"

setup_project() {
    echo ">>> Repulling & Setting up project..."
    cd /app && rm -rf repo
    git clone --depth=1 "$REPO" repo && cd "repo/$SERVICE" || exit 1

    if [ -f ".needs-browser" ]; then
        if ! pgrep -x Xvfb > /dev/null; then
            echo "Starting Xvfb..."
            mkdir -p /tmp/chromium-home/.config /tmp/chromium-home/.cache
            export HOME=/tmp/chromium-home
            export XDG_CONFIG_HOME=/tmp/chromium-home/.config
            export XDG_CACHE_HOME=/tmp/chromium-home/.cache
            export CHROME_BIN=/usr/bin/google-chrome-stable
            export DISPLAY=:99
            Xvfb :99 -screen 0 1024x768x24 +extension GLX +render >/dev/null 2>&1 &
            sleep 1
        fi
    fi

    if [ -f "package.json" ]; then
        [ -f "package-lock.json" ] && npm ci --omit=dev --quiet || npm install --omit=dev --quiet
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        python3 -m venv /app/venv && source /app/venv/bin/activate
        pip install --upgrade pip -q
        [ -f "pyproject.toml" ] && pip install . -q
        [ -f "requirements.txt" ] && pip install -r requirements.txt -q
    else
        echo "Error: No recognizable project type found."
        exit 1
    fi
}

setup_project

while true; do
    echo ">>> Starting app..."
    cd /app/repo/$SERVICE
    
    if [ -f "package.json" ]; then
        node app.js &
    else
        source /app/venv/bin/activate
        if [ -f "app.py" ] && command -v uvicorn &> /dev/null; then
            uvicorn app:app --host 0.0.0.0 --port ${PORT:-7860} &
        else
            python app.py &
        fi
    fi
    
    APP_PID=$!
    wait $APP_PID
    EXIT_CODE=$?
    
    echo ">>> App exited (code $EXIT_CODE). Repulling & Restarting in 3s..."
    sleep 3
    setup_project
done