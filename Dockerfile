FROM node:20-slim

RUN apt-get update && apt-get install -y \
    git python3 python3-pip python3-venv \
    wget gnupg ca-certificates xvfb procps \
    tesseract-ocr libtesseract-dev \
    fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 \
    libatk1.0-0 libxss1 libnss3 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
    libxkbcommon0 libpango-1.0-0 libcairo2 libasound2 \
    && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY route.sh ./route.sh
RUN sed -i 's/\r$//' ./route.sh && chmod +x ./route.sh

#port railway
#EXPOSE 8080

#port hf
#EXPOSE 7860

CMD ["./route.sh"]
