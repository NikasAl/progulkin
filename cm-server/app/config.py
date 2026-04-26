"""
Конфигурация CM Server (Connection Manager).
Общий сервер для signaling и billing нескольких приложений.
"""
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Настройки приложения"""

    # ========================================================================
    # ОКРУЖЕНИЕ
    # ========================================================================
    ENV: str = "dev"
    DEBUG: bool = False

    # ========================================================================
    # API
    # ========================================================================
    API_PREFIX: str = "/cm"
    HOST: str = "0.0.0.0"
    PORT: int = 8002

    # ========================================================================
    # YOOKASSA (ПЛАТЕЖИ)
    # ========================================================================
    YOOKASSA_SHOP_ID: Optional[str] = None
    YOOKASSA_SECRET_KEY: Optional[str] = None

    # ========================================================================
    # REDIS (СИГНАЛЬНЫЙ СЕРВЕР)
    # ========================================================================
    REDIS_URL: str = "redis://localhost:6379/2"
    REDIS_PREFIX: str = "cm:"

    # ========================================================================
    # SIGNALING SERVER (WebSocket Security)
    # ========================================================================
    SIGNALING_PORT: int = 9001
    SIGNALING_HOST: str = "0.0.0.0"
    SIGNALING_AUTH_SECRET: Optional[str] = None  # HMAC secret для аутентификации
    SIGNALING_AUTH_REQUIRED: bool = True  # Требовать аутентификацию
    SIGNALING_MAX_MESSAGE_SIZE: int = 64 * 1024  # 64KB
    SIGNALING_RATE_LIMIT: int = 10  # сообщений в секунду

    # ========================================================================
    # БАЗОВЫЕ ЦЕНЫ
    # ========================================================================
    MIN_PAYMENT_AMOUNT: float = 10.0
    MAX_PAYMENT_AMOUNT: float = 100000.0

    # ========================================================================
    # APP DEEP LINKS (для return_url в YooKassa)
    # ========================================================================
    APP_SCHEMES: dict = {
        "progulkin": "progulkin",
        "starflow": "starflow",
    }

    # ========================================================================
    # BASE URL для веб-версий (опционально)
    # ========================================================================
    BASE_URL: str = "https://kreagenium.ru"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True
    )

    def is_production(self) -> bool:
        return self.ENV == "prod"

    def is_development(self) -> bool:
        return self.ENV == "dev"


settings = Settings()
