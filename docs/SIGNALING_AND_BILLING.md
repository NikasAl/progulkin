# CM Server: Signaling и Billing

**Дата обновления:** 2026-04-26

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                      NGINX (443/80)                         │
├─────────────────────────────────────────────────────────────┤
│                         │                                   │
│    /mv/* ◄──────────────┼──────────────► /cm/*              │
│         │               │                   │               │
│         ▼               │                   ▼               │
│  ┌──────────────┐       │          ┌──────────────┐         │
│  │  mindvector  │       │          │  CM Server   │         │
│  │  :8001       │       │          │  :8002       │         │
│  │              │       │          │              │         │
│  │ - billing    │       │          │ - billing    │         │
│  │ - users      │       │          │ - signaling  │◄── WebSocket
│  │ - concepts   │       │          │   (WS)       │    через 443
│  └──────────────┘       │          └──────────────┘         │
│         │               │               │                   │
│         ▼               │               ▼                   │
│  ┌──────────────┐       │          ┌──────────────┐         │
│  │  PostgreSQL  │       │          │   Redis      │         │
│  │  (mindvector)│       │          │ (сессии,     │         │
│  └──────────────┘       │          │  pub/sub)    │         │
│                         │          └──────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Ключевые особенности

- **Всё через HTTPS 443** - WebSocket signaling работает через тот же порт
- **Не нужно открывать дополнительные порты** на роутере
- **Stateless архитектура** - YooKassa хранит историю платежей
- **Multi-app поддержка** - один сервер для нескольких приложений

---

## Signaling Server

### WebSocket Endpoint

```
wss://kreagenium.ru/cm/ws/signaling
```

### Протокол сообщений

#### Client → Server

**Регистрация:**
```json
{
  "type": "register",
  "deviceId": "uuid-device-id",
  "app": "progulkin",
  "zone": "geo-zone-name",
  "port": 9001
}
```

**Отправка сигнала (WebRTC):**
```json
{
  "type": "signal",
  "to": "target-device-id",
  "signalType": "offer",
  "data": { ... webrtc offer ... }
}
```

**Heartbeat:**
```json
{
  "type": "heartbeat"
}
```

**Запрос списка пиров:**
```json
{
  "type": "get_peers"
}
```

#### Server → Client

**Подтверждение регистрации:**
```json
{
  "type": "registered",
  "deviceId": "your-device-id",
  "peers": [
    {"deviceId": "peer-1", "zone": "zone-name", "ip": "1.2.3.4", "port": 9001}
  ]
}
```

**Входящий сигнал:**
```json
{
  "type": "signal",
  "from": "source-device-id",
  "signalType": "offer|answer|ice-candidate",
  "data": { ... }
}
```

**Новый пир в зоне:**
```json
{
  "type": "peer_joined",
  "peer": {"deviceId": "new-peer", "zone": "zone-name", "ip": "5.6.7.8", "port": 9001}
}
```

**Пир отключился:**
```json
{
  "type": "peer_left",
  "deviceId": "disconnected-peer-id"
}
```

**Ошибка:**
```json
{
  "type": "error",
  "message": "Error description"
}
```

---

## Billing API

### Base URL
```
https://kreagenium.ru/cm
```

### Endpoints

#### Создать платёж
```
POST /billing/create
Content-Type: application/json

{
  "device_id": "uuid",
  "amount": 149,
  "app": "progulkin"
}
```

Response:
```json
{
  "payment_id": "payment-uuid",
  "payment_url": "https://yookassa.ru/...",
  "amount": 149
}
```

#### Создать платёж для приложения
```
POST /billing/create/starflow
Content-Type: application/json

{
  "device_id": "uuid",
  "amount": 79
}
```

#### Проверить статус платежа
```
GET /billing/status/{payment_id}
```

Response:
```json
{
  "payment_id": "...",
  "status": "succeeded",
  "amount": 149,
  "currency": "RUB",
  "is_paid": true,
  "device_id": "...",
  "app": "progulkin"
}
```

#### Быстрая проверка оплаты
```
GET /billing/check/{payment_id}
```

Response:
```json
{
  "payment_id": "...",
  "is_paid": true
}
```

#### Список приложений и продуктов
```
GET /billing/apps
```

#### Цены
```
GET /billing/prices
```

---

## Поддерживаемые приложения

| App | Продукты |
|-----|----------|
| progulkin | 149₽ - Premium (no_ads, unlimited_walks, stats) |
| starflow | 10₽ - Разведчик (10 energy), 25₽ - Командир (30 energy), 79₽ - Адмирал (100 energy) |

---

## Flutter интеграция

### Зависимости

```yaml
dependencies:
  web_socket_channel: ^3.0.1
```

### Signaling клиент

```dart
import 'package:progulkin/services/p2p/signaling_client.dart';

final client = SignalingClient(
  config: SignalingConfig(
    serverUrl: 'wss://kreagenium.ru/cm/ws/signaling',
    deviceId: 'your-device-uuid',
    app: 'progulkin',
    zone: 'geo-zone-name',
  ),
);

// Подключение
await client.connect();

// Слушать события
client.peerJoinedStream.listen((peer) {
  print('New peer: ${peer.deviceId}');
});

client.signalStream.listen((signal) {
  // Обработка WebRTC сигналов
});

// Отправить сигнал
client.sendSignal(targetDeviceId, 'offer', webrtcOffer);
```

### P2P сервис

```dart
import 'package:progulkin/services/p2p/p2p_service.dart';

final p2p = P2PService();

await p2p.start(P2PConfig(
  signalingServerUrl: 'wss://kreagenium.ru/cm/ws/signaling',
  deviceId: 'device-uuid',
  app: 'progulkin',
  zone: 'geo-zone',
));
```

---

## Nginx конфигурация

```nginx
location /cm {
    proxy_pass http://127.0.0.1:8002;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # WebSocket support
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Для long polling и streaming
    proxy_buffering off;
    proxy_read_timeout 86400s;  # 24 часа для WebSocket
}
```

---

## Деплой

```bash
cd /path/to/cm-server
./scripts/deploy.sh
```

Скрипт:
1. Подтягивает изменения из Git
2. Обновляет venv
3. Перезапускает Gunicorn

---

## Мониторинг

### Health check
```
GET /cm/health
```

### Signaling stats
```
GET /cm/signaling/stats
```

Response:
```json
{
  "total_connections": 5,
  "total_zones": 2,
  "zones": {"zone-a": 3, "zone-b": 2}
}
```

### Онлайн устройства
```
GET /cm/signaling/online/progulkin
```

---

## Изменения от 2026-04-26

1. **WebSocket signaling** вместо TCP на порту 9000
   - Работает через HTTPS 443
   - Не нужно открывать дополнительные порты

2. **Удалён устаревший Dart signaling server** (bin/signaling_server.dart)
   - Был на порту 9000
   - Заменён на WebSocket в CM Server

3. **Обновлён Flutter клиент**
   - signalling_client.dart теперь использует WebSocket
   - Обратная совместимость через SignalingConfig

4. **Multi-app архитектура**
   - Поддержка progulkin, starflow и будущих приложений
   - Разделение по app в метаданных
