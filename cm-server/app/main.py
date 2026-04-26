"""
Главный файл FastAPI приложения CM Server.
Connection Manager - общий сервер для signaling и billing.
"""
import logging
from contextlib import asynccontextmanager
import json

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.config import settings
from app.api import api_router
from app.services.redis_service import redis_service

from fastapi.middleware.cors import CORSMiddleware

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
    debug=settings.DEBUG,
    lifespan=lifespan,
    docs_url="/docs" if not settings.is_production() else None,
    redoc_url="/redoc" if not settings.is_production() else None,
)


# ============================================================================
# ОБРАБОТКА ОШИБОК ВАЛИДАЦИИ
# ============================================================================

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Логирует детали ошибки валидации запроса"""
    errors = exc.errors()
    
    # Логируем детали ошибки
    logger.error(f"Validation error on {request.method} {request.url.path}")
    logger.error(f"  Body: {await request.body()}")
    for err in errors:
        logger.error(f"  Error: {err}")
    
    # Возвращаем стандартный ответ
    return JSONResponse(
        status_code=422,
        content={"detail": errors},
    )

# Подключаем роутеры
app.include_router(api_router, prefix=settings.API_PREFIX)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # или указать конкретные origins
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

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
