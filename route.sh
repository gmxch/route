#!/bin/bash

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

sync_project() {
    echo ">>> Syncing & Setting up project..."
    cd /app || exit 1
    
    if [ -d "repo/.git" ]; then
        echo ">>> Repository exists, fetching latest changes..."
        cd repo
        git fetch --all --quiet
        git reset --hard origin/HEAD --quiet || git reset --hard origin/main --quiet || git reset --hard origin/master --quiet
        cd "$SERVICE" || exit 1
    else
        echo ">>> Cloning repository for the first time..."
        rm -rf repo
        git clone --depth=1 "$REPO" repo || exit 1
        cd "repo/$SERVICE" || exit 1
    fi

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
        if [ ! -d "/app/venv" ]; then
            python3 -m venv /app/venv
        fi
        source /app/venv/bin/activate
        pip install --upgrade pip -q
        [ -f "pyproject.toml" ] && pip install . -q
        [ -f "requirements.txt" ] && pip install -r requirements.txt -q
    else
        echo "Error: No recognizable project type found."
        exit 1
    fi
}

sync_project

while true; do
    echo ">>> Starting app..."
    cd /app/repo/$SERVICE || exit 1
    
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
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo ">>> App exited gracefully (code 0). Restarting in 2s..."
        sleep 2
        sync_project 
    else
        echo ">>> App CRASHED (code $EXIT_CODE). Syncing & Restarting in 5s..."
        sleep 5
        sync_project
    fi
done