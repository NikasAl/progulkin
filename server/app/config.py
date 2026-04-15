"""
Конфигурация Progulkin Server.
"""
import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Настройки приложения"""

    # ========================================================================
    # ОКРУЖЕНИЕ
    # ========================================================================
    ENV: str = os.getenv("ENV", "dev")
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"

    # ========================================================================
    # API
    # ========================================================================
    API_PREFIX: str = "/pg"
    HOST: str = "0.0.0.0"
    PORT: int = 8002

    # ========================================================================
    # YOOKASSA (ПЛАТЕЖИ)
    # ========================================================================
    YOOKASSA_SHOP_ID: Optional[str] = os.getenv("YOOKASSA_SHOP_ID")
    YOOKASSA_SECRET_KEY: Optional[str] = os.getenv("YOOKASSA_SECRET_KEY")

    # ========================================================================
    # REDIS (СИГНАЛЬНЫЙ СЕРВЕР)
    # ========================================================================
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/1")
    REDIS_PREFIX: str = "progulkin:"

    # ========================================================================
    # SIGNALING SERVER
    # ========================================================================
    SIGNALING_PORT: int = int(os.getenv("SIGNALING_PORT", "9000"))
    SIGNALING_HOST: str = os.getenv("SIGNALING_HOST", "0.0.0.0")

    # ========================================================================
    # ЦЕНЫ
    # ========================================================================
    MIN_PAYMENT_AMOUNT: float = 10.0
    PREMIUM_PRICE: float = 149.0

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
