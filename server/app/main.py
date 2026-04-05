"""
Главный файл FastAPI приложения Progulkin Server.
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import settings
from app.api import api_router
from app.services.redis_service import redis_service

# Настройка логирования
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("progulkin")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения"""
    # Startup
    logger.info(f"🚀 Progulkin Server starting...")
    logger.info(f"   ENV: {settings.ENV}")
    logger.info(f"   DEBUG: {settings.DEBUG}")

    # Подключаемся к Redis
    try:
        await redis_service.connect()
        logger.info("   Redis: connected")
    except Exception as e:
        logger.warning(f"   Redis: connection failed ({e})")

    yield

    # Shutdown
    logger.info("👋 Progulkin Server shutting down...")
    await redis_service.disconnect()


# Создаём приложение
app = FastAPI(
    title="Progulkin Server",
    description="API для платежей и сигнальный сервер для приложения Прогулкин",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if not settings.is_production() else None,
    redoc_url="/redoc" if not settings.is_production() else None,
)

# Подключаем роутеры
app.include_router(api_router, prefix=settings.API_PREFIX)


# ============================================================================
# ЗАПУСК
# ============================================================================

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
