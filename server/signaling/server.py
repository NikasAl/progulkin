"""
TCP Signaling Server для P2P синхронизации.

Использует Redis для хранения информации о устройствах и зонах.
Это позволяет масштабировать сервер горизонтально.
"""
import asyncio
import json
import logging
from typing import Optional, Dict, Any
from datetime import datetime

from app.config import settings
from app.services.redis_service import redis_service

logger = logging.getLogger(__name__)


class SignalingServer:
    """
    TCP Signaling Server с Redis backend.

    Протокол:
    - Все сообщения в формате JSON
    - Каждое сообщение заканчивается переводом строки (\n)

    Типы сообщений от клиента:
    - register: {type, deviceId, zone, port}
    - heartbeat: {type, deviceId}
    - get_peers: {type, deviceId, zone}
    - leave: {type, deviceId}

    Типы сообщений от сервера:
    - peers: {type, zone, peers: [...]}
    - peer_joined: {type, deviceId, zone, ip, port}
    - peer_left: {type, deviceId, zone}
    - error: {type, message}
    """

    def __init__(self, host: str = None, port: int = None):
        self.host = host or settings.SIGNALING_HOST
        self.port = port or settings.SIGNALING_PORT
        self._server: Optional[asyncio.Server] = None
        self._clients: Dict[str, asyncio.StreamWriter] = {}

    async def start(self):
        """Запускает TCP сервер"""
        self._server = await asyncio.start_server(
            self._handle_client,
            self.host,
            self.port
        )

        addr = self._server.sockets[0].getsockname()
        logger.info(f"🚀 Signaling Server started on {addr[0]}:{addr[1]}")

        async with self._server:
            await self._server.serve_forever()

    async def stop(self):
        """Останавливает сервер"""
        if self._server:
            self._server.close()
            await self._server.wait_closed()
            logger.info("Signaling Server stopped")

    async def _handle_client(
        self,
        reader: asyncio.StreamReader,
        writer: asyncio.StreamWriter
    ):
        """Обрабатывает подключение клиента"""
        addr = writer.get_extra_info('peername')
        device_id: Optional[str] = None

        logger.debug(f"Client connected: {addr}")

        try:
            while True:
                data = await reader.readline()
                if not data:
                    break

                try:
                    message = json.loads(data.decode().strip())
                    device_id = await self._handle_message(message, writer, device_id)
                except json.JSONDecodeError as e:
                    await self._send_error(writer, f"Invalid JSON: {e}")

        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"Error handling client {addr}: {e}")
        finally:
            if device_id:
                await self._handle_disconnect(device_id)
            writer.close()
            await writer.wait_closed()
            logger.debug(f"Client disconnected: {addr}")

    async def _handle_message(
        self,
        message: Dict[str, Any],
        writer: asyncio.StreamWriter,
        current_device_id: Optional[str]
    ) -> Optional[str]:
        """Обрабатывает сообщение от клиента"""
        msg_type = message.get("type")
        device_id = message.get("deviceId")

        if msg_type == "register":
            await self._handle_register(message, writer)
            return device_id

        elif msg_type == "heartbeat":
            if device_id:
                await self._handle_heartbeat(device_id)
                # Сохраняем writer для отправки уведомлений
                self._clients[device_id] = writer
            return current_device_id

        elif msg_type == "get_peers":
            if device_id and message.get("zone"):
                await self._handle_get_peers(device_id, message["zone"], writer)
            return current_device_id

        elif msg_type == "leave":
            if device_id:
                await self._handle_disconnect(device_id)
            return None

        else:
            await self._send_error(writer, f"Unknown message type: {msg_type}")
            return current_device_id

    async def _handle_register(
        self,
        message: Dict[str, Any],
        writer: asyncio.StreamWriter
    ):
        """Регистрирует устройство в зоне"""
        device_id = message["deviceId"]
        zone = message["zone"]
        port = message.get("port", 9001)

        # Получаем IP клиента
        peername = writer.get_extra_info('peername')
        ip = peername[0] if peername else "unknown"

        # Регистрируем в Redis
        await redis_service.register_device(device_id, zone, ip, port)

        # Сохраняем writer для уведомлений
        self._clients[device_id] = writer

        logger.info(f"Device registered: {device_id[:8]}... in zone {zone} ({ip}:{port})")

        # Отправляем список пиров
        await self._send_peers_list(device_id, zone, writer)

        # Уведомляем других в зоне
        await self._notify_peer_joined(device_id, zone, ip, port)

    async def _handle_heartbeat(self, device_id: str):
        """Обновляет TTL устройства"""
        await redis_service.refresh_device_ttl(device_id)

    async def _handle_get_peers(
        self,
        device_id: str,
        zone: str,
        writer: asyncio.StreamWriter
    ):
        """Отправляет список пиров в зоне"""
        await self._send_peers_list(device_id, zone, writer)

    async def _handle_disconnect(self, device_id: str):
        """Обрабатывает отключение устройства"""
        # Получаем данные устройства перед удалением
        device_data = await redis_service.get_device(device_id)
        zone = device_data.get("zone") if device_data else None

        # Удаляем из Redis
        await redis_service.unregister_device(device_id)

        # Удаляем writer
        self._clients.pop(device_id, None)

        logger.info(f"Device disconnected: {device_id[:8]}...")

        # Уведомляем других в зоне
        if zone:
            await self._notify_peer_left(device_id, zone)

    async def _send_peers_list(
        self,
        device_id: str,
        zone: str,
        writer: asyncio.StreamWriter
    ):
        """Отправляет список пиров клиенту"""
        peers = await redis_service.get_zone_peers(zone, device_id)

        message = {
            "type": "peers",
            "zone": zone,
            "peers": peers
        }

        await self._send(writer, message)
        logger.debug(f"Sent {len(peers)} peers to {device_id[:8]}...")

    async def _notify_peer_joined(
        self,
        new_device_id: str,
        zone: str,
        ip: str,
        port: int
    ):
        """Уведомляет всех в зоне о новом пире"""
        message = {
            "type": "peer_joined",
            "deviceId": new_device_id,
            "zone": zone,
            "ip": ip,
            "port": port
        }

        # Получаем все устройства в зоне
        devices = await redis_service.get_zone_devices(zone)

        for device in devices:
            peer_id = device.get("device_id")
            if peer_id and peer_id != new_device_id:
                writer = self._clients.get(peer_id)
                if writer:
                    await self._send(writer, message)

    async def _notify_peer_left(self, device_id: str, zone: str):
        """Уведомляет всех в зоне об уходе пира"""
        message = {
            "type": "peer_left",
            "deviceId": device_id,
            "zone": zone
        }

        devices = await redis_service.get_zone_devices(zone)

        for device in devices:
            peer_id = device.get("device_id")
            if peer_id:
                writer = self._clients.get(peer_id)
                if writer:
                    await self._send(writer, message)

    async def _send(self, writer: asyncio.StreamWriter, message: Dict[str, Any]):
        """Отправляет сообщение клиенту"""
        try:
            data = json.dumps(message) + "\n"
            writer.write(data.encode())
            await writer.drain()
        except Exception as e:
            logger.error(f"Error sending message: {e}")

    async def _send_error(self, writer: asyncio.StreamWriter, message: str):
        """Отправляет сообщение об ошибке"""
        await self._send(writer, {"type": "error", "message": message})


async def run_signaling_server():
    """Запускает сигнальный сервер"""
    server = SignalingServer()
    await server.start()


if __name__ == "__main__":
    asyncio.run(run_signaling_server())
