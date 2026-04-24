"""
Конфигурация CM Server (Connection Manager).
Общий сервер для signaling и billing нескольких приложений.
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
    API_PREFIX: str = "/cm"  # Changed from /pg to /cm
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
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/2")
    REDIS_PREFIX: str = "cm:"

    # ========================================================================
    # SIGNALING SERVER
    # ========================================================================
    SIGNALING_PORT: int = int(os.getenv("SIGNALING_PORT", "9001"))
    SIGNALING_HOST: str = os.getenv("SIGNALING_HOST", "0.0.0.0")

    # ========================================================================
    # БАЗОВЫЕ ЦЕНЫ
    # ========================================================================
    MIN_PAYMENT_AMOUNT: float = 10.0

    # ========================================================================
    # APP DEEP LINKS (для return_url в YooKassa)
    # ========================================================================
    # Формат: {app_name: deep_link_scheme}
    APP_SCHEMES: dict = {
        "progulkin": "progulkin",
        "starflow": "starflow",
    }

    # ========================================================================
    # BASE URL для веб-версий (опционально)
    # ========================================================================
    BASE_URL: str = os.getenv("BASE_URL", "https://kreagenium.ru")

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
