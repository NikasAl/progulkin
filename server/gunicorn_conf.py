"""
Конфигурация Gunicorn для продакшена.

Использование:
    gunicorn -c gunicorn_conf.py app.main:app
"""
import multiprocessing
import os

# ============================================================================
# ОСНОВНЫЕ НАСТРОЙКИ
# ============================================================================

bind = os.getenv("BIND", "0.0.0.0:8002")

# Количество worker-процессов
workers = int(os.getenv("WORKERS", "2"))

# Тип worker - uvicorn для асинхронных приложений FastAPI
worker_class = "uvicorn.workers.UvicornWorker"

# ============================================================================
# ТАЙМАУТЫ
# ============================================================================

timeout = int(os.getenv("TIMEOUT", "60"))
keepalive = int(os.getenv("KEEPALIVE", "5"))
graceful_timeout = int(os.getenv("GRACEFUL_TIMEOUT", "30"))

# ============================================================================
# ЛОГИРОВАНИЕ
# ============================================================================

loglevel = os.getenv("LOG_LEVEL", "info")
accesslog = "-"  # stdout
errorlog = "-"   # stderr
access_log_format = '%(h)s "%(r)s" %(s)s %(b)s %(D)sµs'

# ============================================================================
# ПРОИЗВОДИТЕЛЬНОСТЬ
# ============================================================================

max_requests = int(os.getenv("MAX_REQUESTS", "1000"))
max_requests_jitter = int(max_requests * 0.1)
preload_app = False

# ============================================================================
# БЕЗОПАСНОСТЬ
# ============================================================================

limit_request_line = 4096
limit_request_fields = 100
limit_request_field_size = 8190

# ============================================================================
# ПРОЦЕСС-МЕНЕДЖМЕНТ
# ============================================================================

pidfile = "gunicorn.pid"
daemon = False
print_config = False

# ============================================================================
# HOOKS
# ============================================================================

def on_starting(server):
    print(f"🚀 Gunicorn starting with {workers} workers")
    print(f"   Bind: {bind}")

def when_ready(server):
    print("✅ Gunicorn is ready")

def on_exit(server):
    print("👋 Gunicorn shutting down")
