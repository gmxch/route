FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg wget unzip \
    git python3 python3-pip python3-venv build-essential \
    procps tesseract-ocr libtesseract-dev \
    fonts-liberation fonts-ipafont-gothic libappindicator3-1 \
    libasound2 libatk-bridge2.0-0 libatk1.0-0 libxss1 \
    libnss3 libnspr4 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libgbm1 libxkbcommon0 libpango-1.0-0 libcairo2 \
    libgl1 libglu1-mesa libdrm2 libx11-xcb1 libxcb-dri3-0 libxshmfence1 libdbus-1-3 libcups2 \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN set -eux; \
    URL=$(curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 30 \
      https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json \
      | grep -o 'https://storage.googleapis.com/chrome-for-testing-public/[^"]*linux64/chrome-linux64.zip' | head -n1); \
    test -n "$URL"; \
    curl -fL --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 30 -o /tmp/c.zip "$URL"; \
    unzip -q /tmp/c.zip -d /app; \
    mv /app/chrome-linux64 /app/chrome; \
    rm /tmp/c.zip

ENV HEADLESS=true
ENV CHROME_BIN=/app/chrome/chrome
ENV HOME=/tmp/chromium-home
ENV XDG_CONFIG_HOME=/tmp/chromium-home/.config
ENV XDG_CACHE_HOME=/tmp/chromium-home/.cache

COPY route.sh ./route.sh
RUN sed -i 's/\r$//' ./route.sh && chmod +x ./route.sh

EXPOSE 7860

CMD ["./route.sh"]