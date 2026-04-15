# Progulkin Server
FROM python:3.11-slim

WORKDIR /app

# Устанавливаем зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем код
COPY . .

# Создаём пользователя
RUN useradd -m -u 1000 progulkin && chown -R progulkin:progulkin /app
USER progulkin

# Переменные окружения по умолчанию
ENV ENV=prod
ENV PORT=8002
ENV SIGNALING_PORT=9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8002/pg/health')" || exit 1

# Запускаем API сервер (сигнальный сервер запускается отдельно)
CMD ["gunicorn", "-c", "gunicorn_conf.py", "app.main:app"]
