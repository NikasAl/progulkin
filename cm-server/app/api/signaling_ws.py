"""
WebSocket Signaling Server для CM Server.
Real-time сигнализация через WebSocket (работает через HTTPS 443).

Поддерживает:
- Регистрация устройства в зоне
- Обмен WebRTC signaling сообщениями (offer, answer, ice-candidate)
- Heartbeat для поддержания соединения
- Список пиров в зоне
"""
import logging
import json
from typing import Dict, Set, Optional, Any
from datetime import datetime

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.config import settings
from app.services.redis_service import redis_service

logger = logging.getLogger(__name__)

router = APIRouter()


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
        # device_id -> {app, zone, listen_port, ip, last_seen}
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

        logger.debug(f"WebSocket disconnected: {device_id}")

    async def _cleanup_redis(self, app: str, device_id: str):
        """Очистка данных в Redis при отключении"""
        try:
            await redis_service.remove_online_user(app, device_id)
            await redis_service.delete(f"session:{app}:{device_id}")
        except Exception as e:
            logger.warning(f"Redis cleanup error for {device_id}: {e}")

    def register(self, device_id: str, app: str, zone: str,
                 listen_port: int = 9001, ip: str = "") -> Dict[str, Any]:
        """
        Зарегистрировать устройство с метаданными.
        Возвращает список пиров в зоне.
        """
        self._metadata[device_id] = {
            "app": app,
            "zone": zone,
            "listen_port": listen_port,
            "ip": ip,
            "last_seen": datetime.utcnow().isoformat(),
        }

        # Добавляем в зону
        if zone not in self._zones:
            self._zones[zone] = set()
        self._zones[zone].add(device_id)

        logger.info(f"Device registered: {device_id} in zone '{zone}' (app={app})")

        # Возвращаем список пиров в этой зоне
        return self.get_peers_in_zone(zone, exclude=device_id)

    def update_heartbeat(self, device_id: str) -> bool:
        """Обновить время последней активности"""
        if device_id in self._metadata:
            self._metadata[device_id]["last_seen"] = datetime.utcnow().isoformat()
            return True
        return False

    def get_peers_in_zone(self, zone: str, exclude: str = None) -> list:
        """Получить список пиров в зоне"""
        if zone not in self._zones:
            return []

        peers = []
        for device_id in self._zones[zone]:
            if device_id == exclude:
                continue
            meta = self._metadata.get(device_id)
            if meta and device_id in self._connections:
                peers.append({
                    "deviceId": device_id,
                    "zone": zone,
                    "ip": meta.get("ip", ""),
                    "port": meta.get("listen_port", 9001),
                })
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

    Протокол сообщений (JSON):

    Client -> Server:
    - {"type": "register", "deviceId": "...", "app": "...", "zone": "...", "port": 9001}
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

    try:
        # Принимаем соединение (device_id получим при регистрации)
        # Временный ID до регистрации
        import uuid
        temp_id = str(uuid.uuid4())[:8]
        await manager.connect(websocket, temp_id)

        while True:
            # Получаем сообщение
            try:
                data = await websocket.receive_json()
            except Exception as e:
                logger.warning(f"Invalid JSON received: {e}")
                continue

            msg_type = data.get("type")

            if msg_type == "register":
                # Регистрация устройства
                device_id = data.get("deviceId")
                app = data.get("app", "progulkin")
                zone = data.get("zone", "default")
                listen_port = data.get("port", 9001)

                if not device_id:
                    await websocket.send_json({
                        "type": "error",
                        "message": "deviceId is required for registration"
                    })
                    continue

                # Получаем IP клиента (из заголовков или x-forwarded-for)
                client_host = websocket.client.host if websocket.client else ""
                forwarded = websocket.headers.get("x-forwarded-for", "")
                ip = forwarded.split(",")[0].strip() if forwarded else client_host

                # Перемещаем соединение с temp_id на реальный device_id
                if temp_id in manager._connections:
                    del manager._connections[temp_id]
                manager._connections[device_id] = websocket

                # Регистрируем
                peers = manager.register(device_id, app, zone, listen_port, ip)

                # Сохраняем в Redis
                try:
                    await redis_service.hset(f"session:{app}:{device_id}", "status", "online")
                    await redis_service.hset(f"session:{app}:{device_id}", "zone", zone)
                    await redis_service.expire(f"session:{app}:{device_id}", 300)
                    await redis_service.add_online_user(app, device_id, ttl=300)
                except Exception as e:
                    logger.warning(f"Redis session error: {e}")

                # Оповещаем других в зоне о новом пире
                peer_info = {
                    "deviceId": device_id,
                    "zone": zone,
                    "ip": ip,
                    "port": listen_port,
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
                    peers = manager.get_peers_in_zone(zone, exclude=device_id)
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
    try:
        users = await redis_service.get_online_users(app)
        return {"app": app, "online_count": len(users), "devices": users}
    except Exception as e:
        logger.error(f"Failed to get online users: {e}")
        return {"app": app, "online_count": 0, "devices": []}
