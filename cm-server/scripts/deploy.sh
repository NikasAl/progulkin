#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# DEPLOY SCRIPT FOR CM SERVER
# ==============================================================================
# Использование:
#   ./scripts/deploy.sh sync           # Синхронизировать файлы через rsync
#   ./scripts/deploy.sh restart        # Перезапустить сервер
#   ./scripts/deploy.sh all            # Полный деплой: sync → restart
#   ./scripts/deploy.sh logs           # Показать логи сервера
#   ./scripts/deploy.sh ssh            # Открыть SSH-сессию
#
# Конфигурация через переменные окружения или .env файл
# ==============================================================================

# Конфигурация SSH и удалённого хоста
SSH_USER="${SSH_USER:-nikas}"
SSH_HOST="${SSH_HOST:-turbo}"
SSH_PORT="${SSH_PORT:-22}"
REMOTE_BASE="${REMOTE_BASE:-/home/nikas/prjs/cmserver}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

# Конфигурация проекта
UVICORN_APP="${UVICORN_APP:-app.main:app}"
UVICORN_HOST="${UVICORN_HOST:-0.0.0.0}"
UVICORN_PORT="${UVICORN_PORT:-8002}"
UVICORN_WORKERS="${UVICORN_WORKERS:-1}"
UVICORN_TIMEOUT="${UVICORN_TIMEOUT:-30}"

# Локальные пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Production конфиг
PROD_CONFIG=".env.prod"

usage() {
    cat <<EOF
CM Server Deploy Script

Использование:
  $0 sync           # Синхронизировать файлы проекта через rsync
  $0 restart        # Перезапустить API-сервер
  $0 all            # sync → restart
  $0 logs           # Показать логи сервера
  $0 ssh            # Открыть SSH-сессию
  $0 --help         # Показать эту справку

Переменные окружения:
  SSH_USER      (${SSH_USER})
  SSH_HOST      (${SSH_HOST})
  SSH_PORT      (${SSH_PORT})
  REMOTE_BASE   (${REMOTE_BASE})
  UVICORN_PORT  (${UVICORN_PORT})
EOF
}

# Проверка доступности удалённого хоста
check_ssh() {
    echo "🔌 Проверка соединения с ${SSH_USER}@${SSH_HOST}:${SSH_PORT}..."
    if ! ssh ${SSH_OPTS} -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" "exit 0"; then
        echo "❌ Не удалось подключиться к удалённому хосту."
        exit 1
    fi
    echo "✅ Соединение установлено."
}

# Синхронизация файлов через rsync
sync_files() {
    echo "📦 Синхронизация файлов проекта..."

    # Исключения для rsync
    local exclude_opts="--exclude=.venv --exclude=.git --exclude=__pycache__ --exclude=*.pyc --exclude=.pytest_cache --exclude=.env"

    # Копирование файлов
    rsync -avz --delete \
        ${exclude_opts} \
        -e "ssh -p ${SSH_PORT}" \
        "${PROJECT_ROOT}/" \
        "${SSH_USER}@${SSH_HOST}:${REMOTE_BASE}/"

    echo "✅ Синхронизация завершена."
}

# Перезапуск API-сервера
restart_server() {
    echo "🔄 Перезапуск CM Server..."

    ssh ${SSH_OPTS} -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" <<EOF
cd "${REMOTE_BASE}"

# Проверяем наличие production конфига
if [[ -f "${PROD_CONFIG}" ]]; then
    cp ${PROD_CONFIG} .env
    echo "📝 Используется конфиг: ${PROD_CONFIG}"
fi

if [[ ! -d ".venv" ]]; then
    echo "🆕 Виртуальное окружение не найдено. Создаю..."
    python3 -m venv .venv
fi

source .venv/bin/activate

# Установка зависимостей
if [[ -f "requirements.txt" ]]; then
    REQUIREMENTS_HASH=\$(md5sum requirements.txt | cut -d' ' -f1)
    HASH_FILE=".requirements_hash"
    STORED_HASH=\$(cat \${HASH_FILE} 2>/dev/null || true)

    if [[ "\${REQUIREMENTS_HASH}" != "\${STORED_HASH}" ]]; then
        echo "📦 Обновление зависимостей..."
        pip install --upgrade pip -q
        pip install -r requirements.txt -q
        echo "\${REQUIREMENTS_HASH}" > \${HASH_FILE}
    else
        echo "📦 Зависимости актуальны"
    fi
fi

# Завершаем предыдущие процессы
PID=\$(cat gunicorn.pid 2>/dev/null || true)

if [[ -n "\${PID}" ]] && kill -0 \${PID} 2>/dev/null; then
    echo "🛑 Остановка предыдущего сервера (PID: \${PID})..."
    pkill -P \${PID} 2>/dev/null || true
    kill -TERM \${PID} 2>/dev/null || true
    sleep 2

    if kill -0 \${PID} 2>/dev/null; then
        kill -KILL \${PID} 2>/dev/null || true
        pkill -f "${REMOTE_BASE}/.venv/bin/gunicorn" 2>/dev/null || true
        sleep 1
    fi
else
    pkill -f "${REMOTE_BASE}/.venv/bin/gunicorn" 2>/dev/null || true
fi

# Запускаем gunicorn
echo "🚀 Запуск CM Server на порту ${UVICORN_PORT}..."
export UVICORN_BIND="${UVICORN_HOST}:${UVICORN_PORT}"
export UVICORN_WORKERS="${UVICORN_WORKERS}"
export UVICORN_TIMEOUT="${UVICORN_TIMEOUT}"
export UVICORN_LOG_LEVEL="info"
export ENV="prod"
export DEBUG="false"

nohup gunicorn -c gunicorn_conf.py ${UVICORN_APP} > gunicorn.log 2>&1 &
echo \$! > gunicorn.pid

sleep 2
NEW_PID=\$(cat gunicorn.pid 2>/dev/null || true)
if [[ -n "\${NEW_PID}" ]] && kill -0 \${NEW_PID} 2>/dev/null; then
    WORKERS=\$(pgrep -f "${REMOTE_BASE}/.venv/bin/gunicorn" | wc -l)
    echo "✅ CM Server запущен (PID: \${NEW_PID}, Processes: \${WORKERS})"
    echo "   URL: https://kreagenium.ru/cm/"
else
    echo "❌ Не удалось запустить сервер!"
    echo ""
    echo "📋 Логи:"
    tail -30 gunicorn.log 2>/dev/null || echo "(лог пуст)"
    exit 1
fi
EOF
    echo "✅ Сервер перезапущен."
}

# Просмотр логов
show_logs() {
    echo "📋 Просмотр логов..."
    ssh ${SSH_OPTS} -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" <<EOF
cd "${REMOTE_BASE}"
tail -f gunicorn.log
EOF
}

# Полное развёртывание
deploy_all() {
    echo "🚀 Запуск полного развёртывания..."
    echo ""
    sync_files
    echo ""
    restart_server
    echo ""
    echo "🎉 Развёртывание завершено!"
    echo "   URL: https://kreagenium.ru/cm/"
}

# SSH-сессия
ssh_session() {
    echo "🔌 Подключение к ${SSH_USER}@${SSH_HOST}:${SSH_PORT}..."
    ssh ${SSH_OPTS} -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}"
}

# Основная логика
case "${1:-}" in
    sync)
        check_ssh
        sync_files
        ;;
    restart)
        check_ssh
        restart_server
        ;;
    all)
        check_ssh
        deploy_all
        ;;
    logs)
        show_logs
        ;;
    ssh)
        ssh_session
        ;;
    -h|--help|"")
        usage
        ;;
    *)
        echo "❌ Неизвестная команда: ${1}"
        usage
        exit 1
        ;;
esac
