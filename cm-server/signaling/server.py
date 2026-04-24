"""
WebSocket Signaling Server для CM Server.
Запускается отдельно от HTTP API.
"""
import asyncio
import json
import logging
from typing import Dict, Set, Optional

import websockets
from websockets.server import WebSocketServerProtocol

# Конфигурация
SIGNALING_HOST = "0.0.0.0"
SIGNALING_PORT = 9001

# Логирование
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("signaling")


class SignalingServer:
    """WebSocket сигнальный сервер"""

    def __init__(self):
        # Активные соединения: {app: {user_id: websocket}}
        self.connections: Dict[str, Dict[str, WebSocketServerProtocol]] = {}
        # Обратный маппинг: {websocket: (app, user_id)}
        self.reverse_map: Dict[WebSocketServerProtocol, tuple] = {}

    def get_app_connections(self, app: str) -> Dict[str, WebSocketServerProtocol]:
        """Получить соединения для приложения"""
        if app not in self.connections:
            self.connections[app] = {}
        return self.connections[app]

    async def register(self, websocket: WebSocketServerProtocol, app: str, user_id: str):
        """Зарегистрировать соединение"""
        app_conns = self.get_app_connections(app)
        app_conns[user_id] = websocket
        self.reverse_map[websocket] = (app, user_id)
        logger.info(f"✅ Registered: {app}/{user_id} (total: {len(app_conns)})")

    async def unregister(self, websocket: WebSocketServerProtocol):
        """Удалить соединение"""
        if websocket in self.reverse_map:
            app, user_id = self.reverse_map[websocket]
            del self.reverse_map[websocket]

            if app in self.connections and user_id in self.connections[app]:
                del self.connections[app][user_id]
                logger.info(f"❌ Unregistered: {app}/{user_id}")

    async def send_to_user(self, app: str, user_id: str, message: dict):
        """Отправить сообщение конкретному пользователю"""
        app_conns = self.get_app_connections(app)
        if user_id in app_conns:
            try:
                await app_conns[user_id].send(json.dumps(message))
                return True
            except Exception as e:
                logger.error(f"Send error to {app}/{user_id}: {e}")
        return False

    async def broadcast(self, app: str, message: dict, exclude: Optional[str] = None):
        """Широковещательная отправка"""
        app_conns = self.get_app_connections(app)
        tasks = []
        for user_id, ws in app_conns.items():
            if user_id != exclude:
                tasks.append(ws.send(json.dumps(message)))
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)

    async def handle_message(self, websocket: WebSocketServerProtocol, data: str):
        """Обработка входящего сообщения"""
        try:
            message = json.loads(data)
            msg_type = message.get("type")

            if msg_type == "register":
                # Регистрация пользователя
                app = message.get("app", "progulkin")
                user_id = message.get("user_id")
                if user_id:
                    await self.register(websocket, app, user_id)
                    await websocket.send(json.dumps({"type": "registered", "user_id": user_id}))

            elif msg_type == "signal":
                # Сигнальное сообщение (WebRTC)
                app = message.get("app", "progulkin")
                to_user = message.get("to")
                from_user = self.reverse_map.get(websocket, (None, None))[1]

                if to_user and from_user:
                    success = await self.send_to_user(app, to_user, {
                        "type": "signal",
                        "from": from_user,
                        "data": message.get("data"),
                    })
                    if not success:
                        await websocket.send(json.dumps({
                            "type": "error",
                            "message": f"User {to_user} not found"
                        }))

            elif msg_type == "ping":
                await websocket.send(json.dumps({"type": "pong"}))

        except json.JSONDecodeError:
            logger.warning(f"Invalid JSON from {websocket.remote_address}")
        except Exception as e:
            logger.error(f"Message handling error: {e}")

    async def handler(self, websocket: WebSocketServerProtocol):
        """Обработчик WebSocket соединения"""
        remote = websocket.remote_address
        logger.info(f"🔌 New connection from {remote}")

        try:
            async for message in websocket:
                await self.handle_message(websocket, message)
        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception as e:
            logger.error(f"Connection error: {e}")
        finally:
            await self.unregister(websocket)
            logger.info(f"🔌 Connection closed: {remote}")


async def main():
    """Запуск сервера"""
    server = SignalingServer()

    logger.info(f"🚀 Signaling Server starting on {SIGNALING_HOST}:{SIGNALING_PORT}")

    async with websockets.serve(
        server.handler,
        SIGNALING_HOST,
        SIGNALING_PORT,
        ping_interval=30,
        ping_timeout=10
    ):
        await asyncio.Future()  # Работает бесконечно


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("👋 Shutdown requested")
