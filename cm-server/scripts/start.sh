#!/usr/bin/env bash
# Локальный запуск CM Server

cd "$(dirname "$0")/.."

# Проверяем .env
if [[ ! -f ".env" ]]; then
    echo "⚠️  .env не найден, копирую из .env.example"
    cp .env.example .env
    echo "📝 Отредактируйте .env перед запуском"
fi

# Активируем venv если есть
if [[ -d ".venv" ]]; then
    source .venv/bin/activate
fi

# Запускаем
echo "🚀 Starting CM Server..."
export ENV=dev
export DEBUG=true

uvicorn app.main:app --reload --host 0.0.0.0 --port 8002
