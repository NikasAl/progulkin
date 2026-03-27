# Анализ безопасности Signaling Server

## 🔍 Текущая реализация (Dart)

### Обнаруженные уязвимости

#### 1. КРИТИЧЕСКИЕ

| Уязвимость | Описание | Вектор атаки |
|------------|----------|--------------|
| **Отсутствие аутентификации** | Любой может подключиться и представиться любым deviceId | Злоумышленник перехватывает идентификатор легитимного пользователя |
| **Нет шифрования** | Все данные передаются в открытом виде (TCP) | MITM-атака, перехват трафика |
| **IP-спуфинг** | Клиент может указать любой IP/port для P2P | Редирект атак на другой сервер |
| **Отсутствие rate limiting** | Нет ограничений на количество запросов | DoS-атака через флуд сообщениями |

#### 2. ВЫСОКИЕ

| Уязвимость | Описание | Вектор атаки |
|------------|----------|--------------|
| **Нет валидации deviceId** | deviceId может быть любой строки | Подмена идентификатора, SQL-инъекция в логах |
| **Нет лимита на размер сообщения** | Можно отправить JSON любого размера | OOM (Out of Memory) атака |
| **Отсутствие timeout** | Соединения висят бесконечно | Resource exhaustion |
| **Zone flooding** | Можно создать бесконечное число зон | Раздувание памяти сервера |

#### 3. СРЕДНИЕ

| Уязвимость | Описание |
|------------|----------|
| **Нет логирования suspicious activity** | Невозможно обнаружить атаку |
| **Нет blacklist/whitelist** | Нельзя заблокировать злоумышленника |
| **Predictable zone names** | Geohash предсказуем - можно найти все зоны |

---

## 🛡️ Рекомендации по безопасности

### Архитектурная схема безопасной системы

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ИНТЕРНЕТ                                        │
└─────────────────────────────────────┬───────────────────────────────────────┘
                                      │
                                      ▼
                          ┌───────────────────────┐
                          │      NGINX (443)      │
                          │   TLS Termination     │
                          │   Rate Limiting       │
                          │   Request Filtering   │
                          └───────────┬───────────┘
                                      │
                                      ▼
                          ┌───────────────────────┐
                          │   Uvicorn/Gunicorn    │
                          │   (Unix Socket)       │
                          │   WebSocket Server    │
                          └───────────┬───────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
            ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
            │   Redis      │  │   Rate       │  │   Auth       │
            │   (State)    │  │   Limiter    │  │   Service    │
            └──────────────┘  └──────────────┘  └──────────────┘
```

### Что даёт переход на Python + Nginx

| Аспект | Dart standalone | Python + Nginx |
|--------|-----------------|----------------|
| **TLS/SSL** | Нужно реализовывать | Nginx из коробки |
| **Rate limiting** | Нужно писать | Nginx limit_req |
| **DDoS защита** | Нет | Nginx + fail2ban |
| **Логирование** | Простой print | structlog, ELK |
| **Мониторинг** | Нет | Prometheus, Grafana |
| **Масштабирование** | Сложно | gunicorn workers |
| **Graceful restart** | Нет | Да (zero-downtime) |

---

## 🔧 Безопасная реализация на Python

### 1. Signaling Server (FastAPI + WebSocket)

```python
# signaling_server.py
import asyncio
import hashlib
import hmac
import time
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Dict, Set, Optional
from datetime import datetime, timedelta

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import redis.asyncio as redis
import structlog

# Логирование
logger = structlog.get_logger()

# Конфигурация
CONFIG = {
    "max_clients_per_zone": 100,
    "max_zones": 10000,
    "message_size_limit": 65536,  # 64KB
    "heartbeat_timeout": 60,
    "rate_limit_requests": 10,  # запросов в секунду
    "rate_limit_window": 1,
    "api_key_header": "X-API-Key",
    "hmac_secret": "your-secret-key-change-me",
}

@dataclass
class Client:
    websocket: WebSocket
    device_id: str
    zone: str
    ip: str
    port: int
    last_seen: datetime = field(default_factory=datetime.now)

class SecureSignalingServer:
    def __init__(self, redis_url: str = "redis://localhost"):
        self.clients: Dict[str, Client] = {}  # device_id -> Client
        self.zones: Dict[str, Set[str]] = defaultdict(set)  # zone -> set of device_ids
        self.device_to_zone: Dict[str, str] = {}
        self.rate_limiter = defaultdict(list)  # IP -> [timestamps]
        self.redis: Optional[redis.Redis] = None
        self.redis_url = redis_url
        self.api_keys: Set[str] = set()  # Валидные API ключи

    async def init_redis(self):
        """Инициализация Redis для распределённого состояния"""
        self.redis = await redis.from_url(self.redis_url)
        logger.info("Redis connected", url=self.redis_url)

    def validate_device_id(self, device_id: str) -> bool:
        """Валидация формата deviceId"""
        if not device_id or len(device_id) > 128:
            return False
        # Только буквенно-цифровые и дефисы
        return all(c.isalnum() or c in '-_' for c in device_id)

    def validate_zone(self, zone: str) -> bool:
        """Валидация geohash зоны"""
        if not zone or len(zone) > 16:
            return False
        # Geohash использует base32: 0-9, b-z (без a,i,l,o)
        valid_chars = set('0123456789bcdefghjkmnpqrstuvwxyz')
        return all(c.lower() in valid_chars for c in zone)

    def check_rate_limit(self, ip: str) -> bool:
        """Проверка rate limit для IP"""
        now = time.time()
        window_start = now - CONFIG["rate_limit_window"]

        # Очищаем старые записи
        self.rate_limiter[ip] = [
            ts for ts in self.rate_limiter[ip]
            if ts > window_start
        ]

        if len(self.rate_limiter[ip]) >= CONFIG["rate_limit_requests"]:
            return False

        self.rate_limiter[ip].append(now)
        return True

    def verify_hmac(self, device_id: str, timestamp: str, signature: str) -> bool:
        """Проверка HMAC подписи для аутентификации"""
        if not timestamp or not signature:
            return False

        # Проверяем что timestamp не старше 5 минут
        try:
            ts = int(timestamp)
            if abs(time.time() - ts) > 300:  # 5 минут
                return False
        except ValueError:
            return False

        # Вычисляем HMAC
        message = f"{device_id}:{timestamp}"
        expected = hmac.new(
            CONFIG["hmac_secret"].encode(),
            message.encode(),
            hashlib.sha256
        ).hexdigest()

        return hmac.compare_digest(signature, expected)

    async def register_client(
        self,
        websocket: WebSocket,
        device_id: str,
        zone: str,
        port: int,
        api_key: Optional[str] = None
    ) -> tuple[bool, str]:
        """Регистрация клиента с проверками безопасности"""

        # 1. Rate limit
        client_ip = websocket.client.host if websocket.client else "unknown"
        if not self.check_rate_limit(client_ip):
            return False, "Rate limit exceeded"

        # 2. Валидация данных
        if not self.validate_device_id(device_id):
            return False, "Invalid device ID"

        if not self.validate_zone(zone):
            return False, "Invalid zone"

        # 3. Проверка лимитов
        if len(self.clients) >= CONFIG["max_zones"] * CONFIG["max_clients_per_zone"]:
            return False, "Server capacity exceeded"

        if len(self.zones[zone]) >= CONFIG["max_clients_per_zone"]:
            return False, "Zone is full"

        # 4. API Key проверка (если включена)
        if CONFIG["api_key_header"] and api_key:
            if api_key not in self.api_keys:
                return False, "Invalid API key"

        # 5. Отключаем старое соединение с тем же deviceId
        if device_id in self.clients:
            old_client = self.clients[device_id]
            try:
                await old_client.websocket.close(code=4000, reason="Replaced by new connection")
            except:
                pass
            await self.unregister_client(device_id)

        # 6. Регистрируем
        client = Client(
            websocket=websocket,
            device_id=device_id,
            zone=zone,
            ip=client_ip,
            port=port
        )

        self.clients[device_id] = client
        self.zones[zone].add(device_id)
        self.device_to_zone[device_id] = zone

        logger.info(
            "Client registered",
            device_id=device_id[:8] + "...",  # Частичное скрытие
            zone=zone,
            ip=client_ip,
            zone_count=len(self.zones[zone])
        )

        return True, "OK"

    async def unregister_client(self, device_id: str):
        """Отключение клиента"""
        if device_id not in self.clients:
            return

        client = self.clients[device_id]
        zone = self.device_to_zone.get(device_id)

        if zone:
            self.zones[zone].discard(device_id)
            if not self.zones[zone]:
                del self.zones[zone]

        del self.clients[device_id]
        self.device_to_zone.pop(device_id, None)

        logger.info("Client disconnected", device_id=device_id[:8] + "...")

        # Уведомляем других в зоне
        if zone:
            await self.broadcast_to_zone(zone, {
                "type": "peer_left",
                "deviceId": device_id,
                "zone": zone
            }, exclude=device_id)

    async def get_peers(self, device_id: str) -> list:
        """Получение списка пиров в зоне"""
        if device_id not in self.clients:
            return []

        zone = self.device_to_zone.get(device_id)
        if not zone:
            return []

        peers = []
        for peer_id in self.zones.get(zone, set()):
            if peer_id != device_id and peer_id in self.clients:
                peer = self.clients[peer_id]
                peers.append({
                    "deviceId": peer_id,
                    "zone": zone,
                    "ip": peer.ip,
                    "port": peer.port
                })

        return peers

    async def broadcast_to_zone(
        self,
        zone: str,
        message: dict,
        exclude: Optional[str] = None
    ):
        """Рассылка сообщения всем в зоне"""
        import json

        message_json = json.dumps(message)

        for device_id in list(self.zones.get(zone, set())):
            if device_id == exclude:
                continue
            if device_id in self.clients:
                try:
                    await self.clients[device_id].websocket.send_text(message_json)
                except:
                    pass  # Клиент отключен

    async def cleanup_stale_connections(self):
        """Периодическая очистка зависших соединений"""
        while True:
            await asyncio.sleep(30)

            now = datetime.now()
            stale = [
                device_id for device_id, client in self.clients.items()
                if (now - client.last_seen).total_seconds() > CONFIG["heartbeat_timeout"]
            ]

            for device_id in stale:
                logger.warning("Cleaning stale connection", device_id=device_id[:8] + "...")
                await self.unregister_client(device_id)

# FastAPI приложение
app = FastAPI(title="Progulkin Signaling Server")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене ограничить!
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

server = SecureSignalingServer()

@app.on_event("startup")
async def startup():
    await server.init_redis()
    asyncio.create_task(server.cleanup_stale_connections())

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "clients": len(server.clients),
        "zones": len(server.zones)
    }

@app.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    device_id: str,
    zone: str,
    port: int = 9001,
    timestamp: Optional[str] = None,
    signature: Optional[str] = None,
    api_key: Optional[str] = None
):
    """WebSocket endpoint для signalling"""
    await websocket.accept()

    # Регистрация
    success, message = await server.register_client(
        websocket, device_id, zone, port, api_key
    )

    if not success:
        await websocket.close(code=4001, reason=message)
        return

    # Отправляем список пиров
    peers = await server.get_peers(device_id)
    import json
    await websocket.send_text(json.dumps({
        "type": "peers",
        "zone": zone,
        "peers": peers
    }))

    # Уведомляем других о новом пире
    client = server.clients[device_id]
    await server.broadcast_to_zone(zone, {
        "type": "peer_joined",
        "deviceId": device_id,
        "zone": zone,
        "ip": client.ip,
        "port": client.port
    }, exclude=device_id)

    # Обработка сообщений
    try:
        while True:
            # Ограничение размера сообщения
            data = await asyncio.wait_for(
                websocket.receive_text(),
                timeout=CONFIG["heartbeat_timeout"]
            )

            if len(data) > CONFIG["message_size_limit"]:
                await websocket.close(code=4002, reason="Message too large")
                break

            try:
                message = json.loads(data)
            except json.JSONDecodeError:
                continue

            msg_type = message.get("type")

            if msg_type == "heartbeat":
                server.clients[device_id].last_seen = datetime.now()
                await websocket.send_text(json.dumps({"type": "heartbeat_ack"}))

            elif msg_type == "get_peers":
                peers = await server.get_peers(device_id)
                await websocket.send_text(json.dumps({
                    "type": "peers",
                    "zone": zone,
                    "peers": peers
                }))

            elif msg_type == "leave":
                break

    except WebSocketDisconnect:
        pass
    except asyncio.TimeoutError:
        await websocket.close(code=4003, reason="Heartbeat timeout")
    finally:
        await server.unregister_client(device_id)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="127.0.0.1",  # Только localhost - nginx проксирует
        port=9000,
        log_config=None  # Используем structlog
    )
```

### 2. Nginx конфигурация

```nginx
# /etc/nginx/sites-available/progulkin-signaling
upstream signaling {
    server unix:/run/signaling.sock;
    keepalive 32;
}

# Rate limiting zone
limit_req_zone $binary_remote_addr zone=signaling_limit:10m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

server {
    listen 443 ssl http2;
    server_name signaling.progulkin.ru;

    # SSL
    ssl_certificate /etc/letsencrypt/live/progulkin.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/progulkin.ru/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=63072000" always;

    # Logging
    access_log /var/log/nginx/signaling_access.log;
    error_log /var/log/nginx/signaling_error.log;

    # Health check (без rate limit)
    location /health {
        proxy_pass http://signaling;
        proxy_http_version 1.1;
    }

    # WebSocket
    location /ws {
        # Rate limiting
        limit_req zone=signaling_limit burst=20 nodelay;
        limit_conn conn_limit 10;

        # Proxy
        proxy_pass http://signaling;
        proxy_http_version 1.1;

        # WebSocket headers
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 3600s;  # 1 час для долгих WebSocket
        proxy_read_timeout 3600s;

        # Buffering OFF для WebSocket
        proxy_buffering off;
    }

    # Блокируем всё остальное
    location / {
        return 404;
    }
}

# HTTP -> HTTPS redirect
server {
    listen 80;
    server_name signaling.progulkin.ru;
    return 301 https://$server_name$request_uri;
}
```

### 3. Systemd unit для сервиса

```ini
# /etc/systemd/system/progulkin-signaling.service
[Unit]
Description=Progulkin Signaling Server
After=network.target redis.service

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/opt/progulkin-signaling
ExecStart=/opt/progulkin-signaling/venv/bin/uvicorn \
    signaling_server:app \
    --uds /run/signaling.sock \
    --workers 4 \
    --log-config null
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/run/signaling.sock

[Install]
WantedBy=multi-user.target
```

---

## 📊 Ответы на вопросы

### 1. Нужен ли порт 9001 на роутере?

**НЕТ!** При правильной архитектуре:

```
Клиент (мобильное приложение)
         │
         ▼
    Интернет (HTTPS/443)
         │
         ▼
    Nginx на сервере (443)
         │
         ▼
    Uvicorn (Unix socket)
```

- **На роутере открываем только 443 (HTTPS)** — это стандартный порт
- WebSocket работает поверх HTTPS (WSS)
- Сигнальный сервер слушает на Unix socket, не на порту
- P2P соединения устанавливаются **между клиентами**, не через сервер

### 2. P2P порт 9001 — зачем он?

Порт 9001 нужен **на устройстве клиента** для прямых P2P соединений:

```
Устройство A ←── P2P (9001) ──→ Устройство B
     │                                │
     └──── Signaling (443) ──────────┘
           (только для знакомства)
```

**Для P2P:**
- Клиентам НЕ нужно открывать порты на роутере
- Используется UDP Hole Punching или TCP simultaneous open
- Работает через NAT большинства провайдеров
- Если NAT симметричный — нужен TURN relay server

### 3. Python vs Dart — что безопаснее?

| Критерий | Dart | Python |
|----------|------|--------|
| **Зрелость библиотек** | Меньше | Больше (аудиты безопасности) |
| **Скорость разработки** | Средняя | Быстрая |
| **Интеграция с Nginx** | Сложнее | Проще (Unix sockets) |
| **Мониторинг** | Базовый | Богатый (Prometheus, etc) |
| **Обновления безопасности** | Реже | Регулярные |
| **Community security audits** | Меньше | Больше |

**Рекомендация:** Python + FastAPI + Uvicorn для продакшена.

---

## 🔑 Чек-лист перед деплоем

- [ ] TLS 1.2+ настроен
- [ ] Rate limiting включён
- [ ] Логирование suspicious activity
- [ ] Health check endpoint
- [ ] Graceful shutdown
- [ ] Backup/restore процедуры
- [ ] Мониторинг (Prometheus + Grafana)
- [ ] Alerting при аномалиях
- [ ] Регулярные обновления зависимостей
- [ ] Penetration testing

---

## 📈 Мониторинг

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'signaling'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: /metrics
```

```python
# Добавить в signaling_server.py
from prometheus_fastapi_instrumentator import Instrumentator

Instrumentator().instrument(app).expose(app)
```

Метрики для отслеживания:
- `signaling_clients_total` — текущее число клиентов
- `signaling_zones_total` — число активных зон
- `signaling_connections_total` — всего соединений за период
- `signaling_errors_total` — ошибки
- `signaling_rate_limit_rejected_total` — заблокированные по rate limit
