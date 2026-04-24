"""
Главный файл FastAPI приложения CM Server.
Connection Manager - общий сервер для signaling и billing.
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
logger = logging.getLogger("cm-server")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения"""
    # Startup
    logger.info(f"🚀 CM Server starting...")
    logger.info(f"   ENV: {settings.ENV}")
    logger.info(f"   DEBUG: {settings.DEBUG}")
    logger.info(f"   API_PREFIX: {settings.API_PREFIX}")

    # Подключаемся к Redis
    try:
        await redis_service.connect()
        logger.info("   Redis: connected")
    except Exception as e:
        logger.warning(f"   Redis: connection failed ({e})")

    yield

    # Shutdown
    logger.info("👋 CM Server shutting down...")
    await redis_service.disconnect()


# Создаём приложение
app = FastAPI(
    title="CM Server",
    description="Connection Manager API - signaling и billing для мобильных приложений",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if not settings.is_production() else None,
    redoc_url="/redoc" if not settings.is_production() else None,
)

# Подключаем роутеры
app.include_router(api_router, prefix=settings.API_PREFIX)


# ============================================================================
# КОРНЕВОЙ ENDPOINT
# ============================================================================

@app.get("/")
async def root():
    """Информация о сервере"""
    return {
        "name": "CM Server",
        "version": "1.0.0",
        "status": "running",
        "apps": list(settings.APP_SCHEMES.keys()),
        "endpoints": {
            "health": f"{settings.API_PREFIX}/health",
            "billing": f"{settings.API_PREFIX}/billing",
            "signaling": f"{settings.API_PREFIX}/signaling",
        }
    }


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
