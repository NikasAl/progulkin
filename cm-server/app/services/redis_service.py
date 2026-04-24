"""
Redis Service для CM Server.
Используется для signaling (хранение сессий, очереди сообщений).
"""
import logging
from typing import Optional, Dict, Any, List
import redis.asyncio as redis

from app.config import settings

logger = logging.getLogger(__name__)


class RedisService:
    """Асинхронный сервис Redis"""

    def __init__(self):
        self._client: Optional[redis.Redis] = None

    async def connect(self) -> None:
        """Подключение к Redis"""
        if self._client is not None:
            return

        self._client = redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True
        )
        # Проверяем соединение
        await self._client.ping()

    async def disconnect(self) -> None:
        """Отключение от Redis"""
        if self._client is not None:
            await self._client.close()
            self._client = None

    @property
    def client(self) -> redis.Redis:
        if self._client is None:
            raise RuntimeError("Redis not connected")
        return self._client

    def _key(self, key: str) -> str:
        """Добавляет префикс к ключу"""
        return f"{settings.REDIS_PREFIX}{key}"

    # ========================================================================
    # БАЗОВЫЕ ОПЕРАЦИИ
    # ========================================================================

    async def set(self, key: str, value: str, ex: Optional[int] = None) -> bool:
        """Установить значение"""
        return await self.client.set(self._key(key), value, ex=ex)

    async def get(self, key: str) -> Optional[str]:
        """Получить значение"""
        return await self.client.get(self._key(key))

    async def delete(self, key: str) -> int:
        """Удалить ключ"""
        return await self.client.delete(self._key(key))

    async def exists(self, key: str) -> bool:
        """Проверить существование ключа"""
        return await self.client.exists(self._key(key)) > 0

    async def expire(self, key: str, seconds: int) -> bool:
        """Установить TTL"""
        return await self.client.expire(self._key(key), seconds)

    # ========================================================================
    # HASH ОПЕРАЦИИ (для хранения сессий)
    # ========================================================================

    async def hset(self, name: str, key: str, value: str) -> int:
        """Установить поле в hash"""
        return await self.client.hset(self._key(name), key, value)

    async def hget(self, name: str, key: str) -> Optional[str]:
        """Получить поле из hash"""
        return await self.client.hget(self._key(name), key)

    async def hgetall(self, name: str) -> Dict[str, str]:
        """Получить все поля из hash"""
        return await self.client.hgetall(self._key(name))

    async def hdel(self, name: str, key: str) -> int:
        """Удалить поле из hash"""
        return await self.client.hdel(self._key(name), key)

    # ========================================================================
    # PUB/SUB (для signaling)
    # ========================================================================

    async def publish(self, channel: str, message: str) -> int:
        """Опубликовать сообщение в канал"""
        return await self.client.publish(self._key(channel), message)

    async def subscribe(self, *channels: str):
        """Подписаться на каналы"""
        pubsub = self.client.pubsub()
        await pubsub.subscribe(*[self._key(ch) for ch in channels])
        return pubsub

    # ========================================================================
    # СПИСОК ПОЛЬЗОВАТЕЛЕЙ ONLINE
    # ========================================================================

    async def add_online_user(self, app_name: str, user_id: str, ttl: int = 300) -> None:
        """Добавить пользователя в список онлайн"""
        key = self._key(f"online:{app_name}")
        await self.client.sadd(key, user_id)
        await self.client.expire(key, ttl)

    async def remove_online_user(self, app_name: str, user_id: str) -> None:
        """Удалить пользователя из списка онлайн"""
        key = self._key(f"online:{app_name}")
        await self.client.srem(key, user_id)

    async def get_online_users(self, app_name: str) -> List[str]:
        """Получить список онлайн пользователей"""
        key = self._key(f"online:{app_name}")
        return list(await self.client.smembers(key))

    async def is_user_online(self, app_name: str, user_id: str) -> bool:
        """Проверить онлайн ли пользователь"""
        key = self._key(f"online:{app_name}")
        return await self.client.sismember(key, user_id)


# Глобальный экземпляр
redis_service = RedisService()
