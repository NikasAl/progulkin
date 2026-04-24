FROM python:3.11-slim

WORKDIR /app

# Устанавливаем зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем приложение
COPY . .

# Переменные окружения по умолчанию
ENV ENV=prod
ENV DEBUG=false
ENV HOST=0.0.0.0
ENV PORT=8002

# Открываем порт
EXPOSE 8002

# Запуск через gunicorn
CMD ["gunicorn", "-c", "gunicorn_conf.py", "app.main:app"]
