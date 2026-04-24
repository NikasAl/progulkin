"""
Gunicorn configuration for CM Server.
"""
import os
import multiprocessing

# Bind address
bind = os.getenv("UVICORN_BIND", "0.0.0.0:8002")

# Workers
workers = int(os.getenv("UVICORN_WORKERS", multiprocessing.cpu_count() * 2 + 1))

# Timeout (меньше чем для AI-сервисов, т.к. нет долгих запросов)
timeout = int(os.getenv("UVICORN_TIMEOUT", "30"))

# Worker class
worker_class = "uvicorn.workers.UvicornWorker"

# Logging
loglevel = os.getenv("UVICORN_LOG_LEVEL", "info")
accesslog = "-"
errorlog = "-"

# Keep-alive
keepalive = 5

# Process naming
proc_name = "cm-server"

# В production отключаем reload
reload = os.getenv("ENV", "dev") == "dev"
