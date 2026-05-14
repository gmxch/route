#!/bin/bash

REPO=$(echo "$API_URL" | cut -d '=' -f1)
SERVICE=$(echo "$API_URL" | cut -d '=' -f4)

echo "──────────────────────────────────────────"
echo "DEPLOYER STARTING: $SERVICE"
echo "──────────────────────────────────────────"

cd /app || exit 1
rm -rf repo
git clone --depth=1 "$REPO" repo || { echo "Git clone failed"; exit 1; }
cd "repo/$SERVICE" || { echo "Folder $SERVICE not found"; exit 1; }

rm -rf /tmp/.X* /tmp/.X11-unix
Xvfb :99 -screen 0 1024x768x24 -ac -noreset +extension GLX +render &
export DISPLAY=:99


if [ -f package.json ]; then
    echo "Node.js detected. Installing..."
    npm install --omit=dev --no-package-lock --no-audit --no-fund
    
    echo "Waiting for RAM to stabilize..."
    sleep 5
    
    echo "Launching Node.js App..."
    exec npm start

elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then
    echo "Python detected. Setting up VENV..."
    python3 -m venv venv
    source venv/bin/activate
    
    pip install --upgrade pip
    if [ -f requirements.txt ]; then
        pip install -r requirements.txt
    else
        pip install .
    fi

    if pip list | grep -q playwright; then
        echo "Installing Playwright Browsers..."
        python -m playwright install chromium
    fi

    echo "Waiting for RAM to stabilize..."
    sleep 5

    echo "Launching Python (Uvicorn)..."
    exec uvicorn app:app --host 0.0.0.0 --port ${PORT:-7860}

else
    echo "Error: No project files found!"
    exit 1
fi
