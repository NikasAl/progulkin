#!/bin/bash
# start.sh - Запуск Progulkin Server

set -e

cd "$(dirname "$0")"

# Загружаем переменные окружения
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Определяем режим
ENV=${ENV:-dev}

echo "🚀 Starting Progulkin Server (ENV=$ENV)"

# Запускаем сигнальный сервер в фоне
if [ "$1" != "--api-only" ]; then
    echo "📡 Starting Signaling Server on port ${SIGNALING_PORT:-9000}..."
    python -m signaling.server &
    SIGNALING_PID=$!
    echo "   PID: $SIGNALING_PID"
fi

# Запускаем API сервер
if [ "$ENV" = "prod" ]; then
    echo "🌐 Starting API Server (production)..."
    exec gunicorn -c gunicorn_conf.py app.main:app
else
    echo "🌐 Starting API Server (development)..."
    exec python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8002} --reload
fi
