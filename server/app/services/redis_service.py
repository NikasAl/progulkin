"""
Redis Service для сигнального сервера.
Хранит информацию о подключённых устройствах и зонах.
"""
import json
import logging
from typing import Optional, List, Dict, Any
from datetime import timedelta

import redis.asyncio as aioredis

from app.config import settings

logger = logging.getLogger(__name__)


class RedisService:
    """Сервис для работы с Redis"""

    def __init__(self):
        self._client: Optional[aioredis.Redis] = None
        self.prefix = settings.REDIS_PREFIX

    async def connect(self) -> None:
        """Подключение к Redis"""
        if self._client is None:
            self._client = aioredis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True
            )
            logger.info(f"Connected to Redis: {settings.REDIS_URL}")

    async def disconnect(self) -> None:
        """Отключение от Redis"""
        if self._client:
            await self._client.close()
            self._client = None
            logger.info("Disconnected from Redis")

    @property
    def client(self) -> aioredis.Redis:
        if self._client is None:
            raise RuntimeError("Redis not connected. Call connect() first.")
        return self._client

    def _key(self, *parts: str) -> str:
        """Формирует ключ с префиксом"""
        return f"{self.prefix}{':'.join(parts)}"

    # =========================================================================
    # УСТРОЙСТВА
    # =========================================================================

    async def register_device(
        self,
        device_id: str,
        zone: str,
        ip: str,
        port: int,
        ttl: int = 300
    ) -> None:
        """
        Регистрирует устройство в зоне.

        Args:
            device_id: ID устройства
            zone: Географическая зона (geohash)
            ip: IP адрес устройства
            port: Порт для P2P
            ttl: Время жизни записи в секундах (default 5 мин)
        """
        device_data = {
            "device_id": device_id,
            "zone": zone,
            "ip": ip,
            "port": port,
        }

        pipe = self.client.pipeline()

        # Сохраняем данные устройства
        device_key = self._key("device", device_id)
        pipe.setex(
            device_key,
            timedelta(seconds=ttl),
            json.dumps(device_data)
        )

        # Добавляем устройство в зону
        zone_key = self._key("zone", zone)
        pipe.sadd(zone_key, device_id)
        pipe.expire(zone_key, ttl)

        await pipe.execute()
        logger.debug(f"Registered device {device_id[:8]} in zone {zone}")

    async def unregister_device(self, device_id: str) -> None:
        """Удаляет устройство из всех зон"""
        device_key = self._key("device", device_id)
        device_data = await self.client.get(device_key)

        if device_data:
            data = json.loads(device_data)
            zone = data.get("zone")
            if zone:
                zone_key = self._key("zone", zone)
                await self.client.srem(zone_key, device_id)

        await self.client.delete(device_key)
        logger.debug(f"Unregistered device {device_id[:8]}")

    async def get_device(self, device_id: str) -> Optional[Dict[str, Any]]:
        """Получает данные устройства"""
        device_key = self._key("device", device_id)
        data = await self.client.get(device_key)
        return json.loads(data) if data else None

    async def refresh_device_ttl(self, device_id: str, ttl: int = 300) -> bool:
        """Продлевает время жизни записи устройства"""
        device_key = self._key("device", device_id)
        device_data = await self.client.get(device_key)

        if not device_data:
            return False

        data = json.loads(device_data)
        zone = data.get("zone")

        pipe = self.client.pipeline()
        pipe.expire(device_key, ttl)

        if zone:
            zone_key = self._key("zone", zone)
            pipe.expire(zone_key, ttl)

        await pipe.execute()
        return True

    # =========================================================================
    # ЗОНЫ
    # =========================================================================

    async def get_zone_devices(self, zone: str) -> List[Dict[str, Any]]:
        """Получает список устройств в зоне"""
        zone_key = self._key("zone", zone)
        device_ids = await self.client.smembers(zone_key)

        devices = []
        for device_id in device_ids:
            device_data = await self.get_device(device_id)
            if device_data:
                devices.append(device_data)

        return devices

    async def get_zone_peers(self, zone: str, exclude_device: str) -> List[Dict[str, Any]]:
        """Получает список пиров в зоне (исключая указанное устройство)"""
        devices = await self.get_zone_devices(zone)
        return [d for d in devices if d.get("device_id") != exclude_device]

    # =========================================================================
    # СТАТИСТИКА
    # =========================================================================

    async def get_stats(self) -> Dict[str, Any]:
        """Получает статистику сервера"""
        # Получаем все ключи устройств
        device_keys = await self.client.keys(self._key("device", "*"))
        zone_keys = await self.client.keys(self._key("zone", "*"))

        total_devices = len(device_keys)
        total_zones = len(zone_keys)

        # Подсчитываем устройства по зонам
        zones_stats = {}
        for zone_key in zone_keys:
            zone = zone_key.split(":")[-1]
            count = await self.client.scard(zone_key)
            zones_stats[zone] = count

        return {
            "total_devices": total_devices,
            "total_zones": total_zones,
            "zones": zones_stats,
        }


# Глобальный экземпляр
redis_service = RedisService()
