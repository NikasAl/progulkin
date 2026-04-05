"""
API endpoints для сигнального сервера (HTTP API).
Основная работа идёт через TCP, здесь только статус и статистика.
"""
import logging

from fastapi import APIRouter

from app.services.redis_service import redis_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/signaling/stats")
async def get_signaling_stats():
    """
    Получает статистику сигнального сервера.

    Возвращает:
    - total_devices: всего устройств онлайн
    - total_zones: всего активных зон
    - zones: детализация по зонам
    """
    try:
        stats = await redis_service.get_stats()
        return {
            "status": "ok",
            **stats
        }
    except Exception as e:
        logger.error(f"Failed to get stats: {e}")
        return {
            "status": "error",
            "error": str(e),
            "total_devices": 0,
            "total_zones": 0,
            "zones": {}
        }


@router.get("/signaling/health")
async def signaling_health():
    """Health check для сигнального сервера"""
    try:
        # Проверяем подключение к Redis
        await redis_service.client.ping()
        return {"status": "healthy", "redis": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}


@router.get("/zone/{zone}/devices")
async def get_zone_devices(zone: str):
    """
    Получает список устройств в зоне.

    - **zone**: Geohash зоны

    Возвращает список устройств с их IP и портами.
    """
    try:
        devices = await redis_service.get_zone_devices(zone)
        return {
            "zone": zone,
            "count": len(devices),
            "devices": devices
        }
    except Exception as e:
        logger.error(f"Failed to get zone devices: {e}")
        raise
