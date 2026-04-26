"""
WebSocket Signaling Server для CM Server.
Real-time сигнализация через WebSocket (работает через HTTPS 443).

Безопасность:
- HMAC-аутентификация при регистрации
- Rate limiting на уровне соединения
- Валидация всех входных данных
- Ограничение размера сообщений
"""
import logging
import json
import hmac
import hashlib
import re
import time
from typing import Dict, Set, Optional, Any
from datetime import datetime
from collections import defaultdict

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.config import settings
from app.services.redis_service import redis_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================================
# SECURITY UTILITIES
# ============================================================================

def validate_device_id(device_id: str) -> bool:
    """Валидация device_id (UUID формат)"""
    if not device_id or len(device_id) > 128:
        return False
    # UUID v4 формат: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    uuid_pattern = r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
    return bool(re.match(uuid_pattern, device_id.lower()))


def validate_zone(zone: str) -> bool:
    """Валидация имени зоны"""
    if not zone or len(zone) > 64:
        return False
    # Только безопасные символы
    return bool(re.match(r'^[a-zA-Z0-9_-]+$', zone))


def validate_app(app: str) -> bool:
    """Валидация имени приложения"""
    if not app or len(app) > 32:
        return False
    return bool(re.match(r'^[a-z][a-z0-9_]*$', app))


def verify_auth_token(device_id: str, timestamp: str, signature: str) -> bool:
    """
    Проверка HMAC-подписи регистрации.

    Формула: signature = HMAC-SHA256(secret, device_id:timestamp)
    """
    if not settings.SIGNALING_AUTH_SECRET:
        # Если секрет не задан, в dev режиме разрешаем
        if settings.is_development():
            logger.warning("AUTH_SECRET not set, allowing unauthenticated connection (dev mode)")
            return True
        return False

    try:
        ts = int(timestamp)
        # Проверяем, что timestamp не старше 5 минут
        if abs(time.time() - ts) > 300:
            logger.warning(f"Auth timestamp expired for {device_id}")
            return False
    except (ValueError, TypeError):
        return False

    # Вычисляем ожидаемую подпись
    message = f"{device_id}:{timestamp}"
    expected = hmac.new(
        settings.SIGNALING_AUTH_SECRET.encode(),
        message.encode(),
        hashlib.sha256
    ).hexdigest()

    # Constant-time comparison
    return hmac.compare_digest(signature, expected)


def log_security_event(event_type: str, details: dict, ip: str = ""):
    """Логирование событий безопасности"""
    logger.warning(f"SECURITY [{event_type}] ip={ip} - {details}")


# ============================================================================
# RATE LIMITER
# ============================================================================

class RateLimiter:
    """Простой rate limiter на уровне соединения"""

    def __init__(self, max_per_second: int = 10):
        self.max_per_second = max_per_second
        self._requests: Dict[str, list] = defaultdict(list)

    def check(self, client_id: str) -> bool:
        """Проверить, разрешён ли запрос"""
        now = time.time()
        requests = self._requests[client_id]

        # Удаляем старые запросы (старше 1 секунды)
        requests[:] = [t for t in requests if now - t < 1.0]

        if len(requests) >= self.max_per_second:
            return False

        requests.append(now)
        return True

    def cleanup(self, client_id: str):
        """Очистить счётчик при отключении"""
        self._requests.pop(client_id, None)


# Глобальный rate limiter
rate_limiter = RateLimiter(max_per_second=settings.SIGNALING_RATE_LIMIT)


# ============================================================================
# CONNECTION MANAGER
# ============================================================================

class ConnectionManager:
    """
    Управляет WebSocket соединениями.
    Хранит активные соединения и их метаданные.
    """

    def __init__(self):
        # device_id -> WebSocket
        self._connections: Dict[str, WebSocket] = {}
        # device_id -> {app, zone, listen_port, ip, last_seen, hide_ip}
        self._metadata: Dict[str, Dict[str, Any]] = {}
        # zone -> set of device_ids
        self._zones: Dict[str, Set[str]] = {}

    async def connect(self, websocket: WebSocket, device_id: str):
        """Принять новое WebSocket соединение"""
        await websocket.accept()
        self._connections[device_id] = websocket
        logger.debug(f"WebSocket connected: {device_id}")

    def disconnect(self, device_id: str):
        """Отключить и удалить соединение"""
        self._connections.pop(device_id, None)

        # Удаляем из зоны
        metadata = self._metadata.pop(device_id, None)
        if metadata:
            zone = metadata.get("zone")
            app = metadata.get("app")
            if zone and zone in self._zones:
                self._zones[zone].discard(device_id)
                if not self._zones[zone]:
                    del self._zones[zone]

            # Удаляем из Redis
            if app:
                import asyncio
                asyncio.create_task(self._cleanup_redis(app, device_id))

        # Очищаем rate limiter
        rate_limiter.cleanup(device_id)

        logger.debug(f"WebSocket disconnected: {device_id}")

    async def _cleanup_redis(self, app: str, device_id: str):
        """Очистка данных в Redis при отключении"""
        try:
            await redis_service.remove_online_user(app, device_id)
            await redis_service.delete(f"session:{app}:{device_id}")
        except Exception as e:
            logger.warning(f"Redis cleanup error for {device_id}: {e}")

    def register(self, device_id: str, app: str, zone: str,
                 listen_port: int = 9001, ip: str = "",
                 hide_ip: bool = True) -> Dict[str, Any]:
        """
        Зарегистрировать устройство с метаданными.
        Возвращает список пиров в зоне.
        """
        self._metadata[device_id] = {
            "app": app,
            "zone": zone,
            "listen_port": listen_port,
            "ip": ip,
            "hide_ip": hide_ip,  # Скрывать IP от других
            "last_seen": datetime.utcnow().isoformat(),
        }

        # Добавляем в зону
        if zone not in self._zones:
            self._zones[zone] = set()
        self._zones[zone].add(device_id)

        logger.info(f"Device registered: {device_id} in zone '{zone}' (app={app})")

        # Возвращаем список пиров в этой зоне
        return self.get_peers_in_zone(zone, exclude=device_id, for_device=device_id)

    def update_heartbeat(self, device_id: str) -> bool:
        """Обновить время последней активности"""
        if device_id in self._metadata:
            self._metadata[device_id]["last_seen"] = datetime.utcnow().isoformat()
            return True
        return False

    def get_peers_in_zone(self, zone: str, exclude: str = None,
                          for_device: str = None) -> list:
        """
        Получить список пиров в зоне.

        Если hide_ip=True у пира, IP не раскрывается.
        """
        if zone not in self._zones:
            return []

        # Проверяем, хочет ли запрашивающий скрыть свой IP
        requester_meta = self._metadata.get(for_device, {})
        requester_hide_ip = requester_meta.get("hide_ip", True)

        peers = []
        for device_id in self._zones[zone]:
            if device_id == exclude:
                continue
            meta = self._metadata.get(device_id)
            if meta and device_id in self._connections:
                peer_info = {
                    "deviceId": device_id,
                    "zone": zone,
                }

                # Раскрываем IP только если оба пользователя согласны
                # (пока скрываем IP по умолчанию для всех)
                # В будущем можно добавить настройку приватности
                # if not meta.get("hide_ip", True) and not requester_hide_ip:
                #     peer_info["ip"] = meta.get("ip", "")
                #     peer_info["port"] = meta.get("listen_port", 9001)

                peers.append(peer_info)
        return peers

    async def send_to_device(self, device_id: str, message: dict) -> bool:
        """Отправить сообщение конкретному устройству"""
        websocket = self._connections.get(device_id)
        if websocket:
            try:
                await websocket.send_json(message)
                return True
            except Exception as e:
                logger.warning(f"Failed to send to {device_id}: {e}")
        return False

    async def broadcast_to_zone(self, zone: str, message: dict,
                                 exclude: str = None):
        """Разослать сообщение всем в зоне"""
        if zone not in self._zones:
            return

        for device_id in list(self._zones[zone]):
            if device_id == exclude:
                continue
            await self.send_to_device(device_id, message)

    def get_stats(self) -> dict:
        """Статистика соединений"""
        return {
            "total_connections": len(self._connections),
            "total_zones": len(self._zones),
            "zones": {zone: len(devices) for zone, devices in self._zones.items()},
        }


# Глобальный менеджер соединений
manager = ConnectionManager()


# ============================================================================
# WEBSOCKET ENDPOINT
# ============================================================================

@router.websocket("/ws/signaling")
async def signaling_websocket(websocket: WebSocket):
    """
    WebSocket endpoint для signaling.

    Безопасность:
    - HMAC-аутентификация при регистрации
    - Rate limiting: 10 msg/sec
    - Максимальный размер сообщения: 64KB
    - Валидация всех полей

    Протокол сообщений (JSON):

    Client -> Server:
    - {"type": "register", "deviceId": "...", "app": "...", "zone": "...",
       "timestamp": 1234567890, "signature": "hmac-sha256-hex"}
    - {"type": "signal", "to": "target_device_id", "signalType": "offer|answer|ice-candidate", "data": {...}}
    - {"type": "heartbeat"}
    - {"type": "get_peers"}

    Server -> Client:
    - {"type": "registered", "peers": [...]}
    - {"type": "peers", "peers": [...]}
    - {"type": "signal", "from": "source_device_id", "signalType": "...", "data": {...}}
    - {"type": "peer_joined", "peer": {...}}
    - {"type": "peer_left", "deviceId": "..."}
    - {"type": "heartbeat_ack"}
    - {"type": "error", "message": "..."}
    """
    device_id = None
    client_ip = ""

    try:
        # Получаем IP клиента
        client_host = websocket.client.host if websocket.client else ""
        forwarded = websocket.headers.get("x-forwarded-for", "")
        client_ip = forwarded.split(",")[0].strip() if forwarded else client_host

        # Принимаем соединение (device_id получим при регистрации)
        import uuid
        temp_id = str(uuid.uuid4())[:8]
        await manager.connect(websocket, temp_id)

        while True:
            # Получаем сообщение
            try:
                raw_data = await websocket.receive_text()
            except Exception as e:
                logger.warning(f"Invalid WebSocket frame: {e}")
                break

            # Проверяем размер сообщения
            if len(raw_data) > settings.SIGNALING_MAX_MESSAGE_SIZE:
                await websocket.send_json({
                    "type": "error",
                    "message": "Message too large"
                })
                log_security_event("OVERSIZE_MESSAGE", {"size": len(raw_data)}, client_ip)
                continue

            # Парсим JSON
            try:
                data = json.loads(raw_data)
            except json.JSONDecodeError as e:
                await websocket.send_json({
                    "type": "error",
                    "message": "Invalid JSON"
                })
                continue

            msg_type = data.get("type")

            # Rate limiting (после регистрации)
            if device_id and not rate_limiter.check(device_id):
                await websocket.send_json({
                    "type": "error",
                    "message": "Rate limit exceeded"
                })
                log_security_event("RATE_LIMIT", {"device_id": device_id}, client_ip)
                continue

            if msg_type == "register":
                # Регистрация устройства
                device_id = data.get("deviceId")
                app = data.get("app", "progulkin")
                zone = data.get("zone", "default")
                listen_port = data.get("port", 9001)
                timestamp = data.get("timestamp", "")
                signature = data.get("signature", "")

                # Валидация
                if not validate_device_id(device_id):
                    await websocket.send_json({
                        "type": "error",
                        "message": "Invalid deviceId format"
                    })
                    log_security_event("INVALID_DEVICE_ID", {"device_id": str(device_id)[:32]}, client_ip)
                    continue

                if not validate_app(app):
                    await websocket.send_json({
                        "type": "error",
                        "message": "Invalid app name"
                    })
                    continue

                if not validate_zone(zone):
                    await websocket.send_json({
                        "type": "error",
                        "message": "Invalid zone name"
                    })
                    log_security_event("INVALID_ZONE", {"zone": str(zone)[:32]}, client_ip)
                    continue

                if not isinstance(listen_port, int) or listen_port < 1 or listen_port > 65535:
                    listen_port = 9001

                # Аутентификация
                if settings.SIGNALING_AUTH_REQUIRED:
                    if not verify_auth_token(device_id, timestamp, signature):
                        await websocket.send_json({
                            "type": "error",
                            "message": "Authentication failed"
                        })
                        log_security_event("AUTH_FAILED", {"device_id": device_id}, client_ip)
                        await websocket.close(code=4001, reason="Authentication failed")
                        return

                # Перемещаем соединение с temp_id на реальный device_id
                if temp_id in manager._connections:
                    del manager._connections[temp_id]
                manager._connections[device_id] = websocket

                # Регистрируем (IP скрыт по умолчанию)
                peers = manager.register(device_id, app, zone, listen_port, client_ip, hide_ip=True)

                # Сохраняем в Redis
                try:
                    await redis_service.hset(f"session:{app}:{device_id}", "status", "online")
                    await redis_service.hset(f"session:{app}:{device_id}", "zone", zone)
                    await redis_service.expire(f"session:{app}:{device_id}", 300)
                    await redis_service.add_online_user(app, device_id, ttl=300)
                except Exception as e:
                    logger.warning(f"Redis session error: {e}")

                # Оповещаем других в зоне о новом пире
                # IP не раскрываем
                peer_info = {
                    "deviceId": device_id,
                    "zone": zone,
                }
                await manager.broadcast_to_zone(zone, {
                    "type": "peer_joined",
                    "peer": peer_info
                }, exclude=device_id)

                # Отправляем подтверждение и список пиров
                await websocket.send_json({
                    "type": "registered",
                    "deviceId": device_id,
                    "peers": peers,
                })

                logger.info(f"Device {device_id} registered in zone '{zone}' with {len(peers)} peers")

            elif msg_type == "signal":
                # Пересылка signaling сообщения
                if not device_id:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Not registered"
                    })
                    continue

                target_device = data.get("to")
                signal_type = data.get("signalType")
                signal_data = data.get("data")

                if not target_device:
                    await websocket.send_json({
                        "type": "error",
                        "message": "target 'to' device is required"
                    })
                    continue

                # Валидация signalType
                valid_signal_types = {"offer", "answer", "ice-candidate"}
                if signal_type not in valid_signal_types:
                    await websocket.send_json({
                        "type": "error",
                        "message": f"Invalid signalType. Must be one of: {valid_signal_types}"
                    })
                    continue

                # Отправляем целевому устройству
                success = await manager.send_to_device(target_device, {
                    "type": "signal",
                    "from": device_id,
                    "signalType": signal_type,
                    "data": signal_data,
                })

                if not success:
                    await websocket.send_json({
                        "type": "error",
                        "message": f"Device {target_device} not found or offline"
                    })

            elif msg_type == "heartbeat":
                # Heartbeat
                if device_id:
                    manager.update_heartbeat(device_id)
                    # Продлеваем Redis сессию
                    meta = manager._metadata.get(device_id)
                    if meta:
                        app = meta.get("app", "progulkin")
                        try:
                            await redis_service.expire(f"session:{app}:{device_id}", 300)
                            await redis_service.add_online_user(app, device_id, ttl=300)
                        except Exception:
                            pass

                await websocket.send_json({"type": "heartbeat_ack"})

            elif msg_type == "get_peers":
                # Запрос списка пиров
                if not device_id:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Not registered"
                    })
                    continue

                meta = manager._metadata.get(device_id)
                if meta:
                    zone = meta.get("zone")
                    peers = manager.get_peers_in_zone(zone, exclude=device_id, for_device=device_id)
                    await websocket.send_json({
                        "type": "peers",
                        "peers": peers,
                    })

            else:
                await websocket.send_json({
                    "type": "error",
                    "message": f"Unknown message type: {msg_type}"
                })

    except WebSocketDisconnect:
        logger.debug(f"WebSocket disconnected: {device_id or temp_id}")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        if device_id:
            # Оповещаем других об отключении
            meta = manager._metadata.get(device_id)
            if meta:
                zone = meta.get("zone")
                await manager.broadcast_to_zone(zone, {
                    "type": "peer_left",
                    "deviceId": device_id,
                }, exclude=device_id)

            manager.disconnect(device_id)
        else:
            manager.disconnect(temp_id)


# ============================================================================
# REST ENDPOINTS для мониторинга
# ============================================================================

@router.get("/signaling/stats")
async def get_signaling_stats():
    """Статистика signaling сервера"""
    return manager.get_stats()


@router.get("/signaling/online/{app}")
async def get_online_devices(app: str):
    """Список онлайн устройств для приложения"""
    if not validate_app(app):
        return {"error": "Invalid app name"}

    try:
        users = await redis_service.get_online_users(app)
        # Возвращаем только количество, не раскрываем ID
        return {"app": app, "online_count": len(users)}
    except Exception as e:
        logger.error(f"Failed to get online users: {e}")
        return {"app": app, "online_count": 0}
