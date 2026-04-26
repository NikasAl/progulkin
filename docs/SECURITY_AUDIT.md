# Аудит безопасности: CM Server и Flutter клиент

**Дата:** 2026-04-26
**Версия:** 1.0
**Статус:** Требуются исправления

---

## Критичность уязвимостей

| Уровень | Описание |
|---------|----------|
| 🔴 **Критический** | Позволяет получить полный контроль или доступ к данным |
| 🟠 **Высокий** | Позволяет получить доступ к функциям других пользователей |
| 🟡 **Средний** | Позволяет получить информацию о системе или пользователях |
| 🟢 **Низкий** | Минимальное влияние, требует сложных условий |

---

## 1. WebSocket Signaling Server

### 🔴 Критический: Отсутствие аутентификации

**Проблема:**
Любой может подключиться к WebSocket и зарегистрироваться с любым `deviceId`.

```javascript
// Атакующий может представиться любым устройством
ws.send(JSON.stringify({
  "type": "register",
  "deviceId": "victim-device-uuid",  // чужой ID
  "app": "progulkin",
  "zone": "some-zone"
}));
```

**Последствия:**
- Перехват сообщений, предназначенных другому пользователю
- Отправка сигналов от чужого имени
- Кража IP-адресов других пользователей

**Решение:**
```python
# Добавить HMAC-аутентификацию
def verify_auth(device_id: str, timestamp: str, signature: str, secret: str) -> bool:
    """Проверка HMAC подписи"""
    expected = hmac.new(
        secret.encode(),
        f"{device_id}:{timestamp}".encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, expected)
```

---

### 🟠 Высокий: Раскрытие IP-адресов пользователей

**Проблема:**
Сервер рассылает IP-адреса всех пользователей в зоне.

```json
{
  "type": "peers",
  "peers": [
    {"deviceId": "user-1", "ip": "192.168.1.50", "port": 9001}
  ]
}
```

**Последствия:**
- Нарушение приватности
- Возможность DDoS-атак на конкретных пользователей
- Геолокация по IP

**Решение:**
- Не раскрывать IP без согласия пользователя
- Использовать relay-сервер для P2P соединений
- Или шифровать IP в signaling сообщениях

---

### 🟠 Высокий: Нет rate limiting

**Проблема:**
Атакующий может отправить тысячи сообщений в секунду.

**Последствия:**
- DoS-атака на сервер
- Spam другим пользователям
- Исчерпание ресурсов Redis

**Решение:**
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.websocket("/ws/signaling")
@limiter.limit("10/second")
async def signaling_websocket(websocket: WebSocket):
    ...
```

---

### 🟡 Средний: Нет валидации размера сообщений

**Проблема:**
Можно отправить сообщение размером 100MB.

**Последствия:**
- Исчерпание памяти сервера
- DoS-атака

**Решение:**
```python
MAX_MESSAGE_SIZE = 64 * 1024  # 64KB

data = await websocket.receive_json()
if len(json.dumps(data)) > MAX_MESSAGE_SIZE:
    await websocket.close(code=1009, reason="Message too large")
    return
```

---

### 🟡 Средний: Нет валидации zone

**Проблема:**
Атакующий может указать любую зону, включая специальные символы.

```javascript
{"type": "register", "zone": "../../../etc/passwd"}
```

**Последствия:**
- Возможность injection-атак
- Polluting Redis keyspace

**Решение:**
```python
import re

def validate_zone(zone: str) -> bool:
    """Валидация имени зоны"""
    return bool(re.match(r'^[a-zA-Z0-9_-]{1,64}$', zone))
```

---

## 2. Billing API

### 🟠 Высокий: Нет аутентификации при создании платежа

**Проблема:**
Любой может создать платёж от чужого `device_id`.

```bash
curl -X POST https://kreagenium.ru/cm/billing/create \
  -H "Content-Type: application/json" \
  -d '{"device_id": "victim-uuid", "amount": 1000, "app": "progulkin"}'
```

**Последствия:**
- Создание платежей от чужого имени
- Spam аккаунта жертвы платёжами

**Решение:**
- Требовать HMAC-подпись с секретом, известным только клиенту
- Или использовать CAPTCHA для анонимных платежей

---

### 🟡 Средний: Информация о платёжах доступна по ID

**Проблема:**
Любой может узнать статус любого платежа по его ID.

```bash
curl https://kreagenium.ru/cm/billing/status/2b12345-...
```

**Последствия:**
- Раскрытие информации о покупках
- Возможно перебор payment_id (UUID v4 достаточно безопасен, но YooKassa может использовать другие форматы)

**Решение:**
- Добавить проверку: только владелец device_id может проверять статус
- Или требовать подпись запроса

---

### 🟡 Средний: Нет защиты от replay-атак

**Проблема:**
Запрос на создание платежа можно перехватить и повторить.

**Решение:**
- Добавить timestamp и nonce в запрос
- Отвергать запросы старше 5 минут
- Хранить использованные nonce в Redis

---

### 🟢 Низкий: Минимальная сумма не валидируется строго

**Проблема:**
`amount` может быть отрицательным или очень большим.

**Решение:**
```python
if amount < settings.MIN_PAYMENT_AMOUNT or amount > 100000:
    raise HTTPException(400, "Invalid amount")
```

---

## 3. Redis

### 🟡 Средний: Нет шифрования соединения

**Проблема:**
Данные передаются в открытом виде между сервером и Redis.

**Решение:**
- Использовать TLS для Redis (redis:// → rediss://)
- Или разместить Redis на localhost только

---

### 🟡 Средний: Нет аутентификации Redis

**Проблема:**
Если Redis доступен из сети, любой может читать/писать данные.

**Решение:**
```redis
# redis.conf
requirepass "strong-random-password"
bind 127.0.0.1
```

---

## 4. Nginx

### 🟡 Средний: Нет ограничения размера request body

**Решение:**
```nginx
client_max_body_size 1m;
```

---

### 🟡 Средний: Нет security headers

**Решение:**
```nginx
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Content-Security-Policy "default-src 'self'" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

---

## 5. Flutter клиент

### 🟠 Высокий: Секреты в коде

**Проблема:**
Если добавить API ключ или HMAC secret в код, его можно извлечь.

**Решение:**
- Не хранить секреты в коде
- Использовать device-specific ключи (получать с сервера при первом запуске)
- Использовать Flutter Obfuscation

---

### 🟡 Средний: Нет certificate pinning

**Проблема:**
MITM-атака возможна при компрометации CA.

**Решение:**
```dart
// Использовать сертификат-пиннинг для WebSocket
import 'package:http/io_client.dart';
import 'dart:io';

SecurityContext context = SecurityContext();
context.setTrustedCertificatesBytes(certBytes);
HttpClient client = HttpClient(context: context);
```

---

### 🟡 Средний: Логирование чувствительных данных

**Проблема:**
Debug логи могут содержать deviceId, payment_id и т.д.

**Решение:**
```dart
// В релизе отключить debug логи
void debugPrint(String? message, {int? wrapWidth}) {
  assert(() {
    print(message);
    return true;
  }());
}
```

---

## План исправлений

### Фаза 1: Критические (выполнить немедленно)

1. ✅ Добавить HMAC-аутентификацию для WebSocket
2. ✅ Добавить rate limiting
3. ✅ Валидация всех входных данных

### Фаза 2: Высокие (в течение недели)

4. Скрыть IP-адреса пользователей
5. Добавить аутентификацию для billing API
6. Настроить security headers в nginx

### Фаза 3: Средние (в течение месяца)

7. Настроить TLS для Redis
8. Добавить certificate pinning в Flutter
9. Защита от replay-атак

---

## Реализация HMAC-аутентификации

### Сервер (signaling_ws.py)

```python
import hmac
import hashlib
import time

AUTH_SECRET = settings.SIGNALING_AUTH_SECRET  # добавить в config
AUTH_MAX_AGE = 300  # 5 минут

def verify_auth_token(device_id: str, timestamp: str, signature: str) -> bool:
    """Проверка HMAC-подписи регистрации"""
    
    # Проверяем timestamp
    try:
        ts = int(timestamp)
        if abs(time.time() - ts) > AUTH_MAX_AGE:
            return False
    except ValueError:
        return False
    
    # Проверяем signature
    message = f"{device_id}:{timestamp}"
    expected = hmac.new(
        AUTH_SECRET.encode(),
        message.encode(),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected)

# В обработчике register:
if msg_type == "register":
    device_id = data.get("deviceId")
    timestamp = data.get("timestamp")
    signature = data.get("signature")
    
    if not verify_auth_token(device_id, timestamp, signature):
        await websocket.send_json({
            "type": "error",
            "message": "Authentication failed"
        })
        await websocket.close()
        return
```

### Клиент (signaling_client.dart)

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SignalingConfig {
  final String serverUrl;
  final String deviceId;
  final String app;
  final String zone;
  final String? authSecret;  // HMAC secret
  // ...
}

class SignalingClient {
  Map<String, dynamic> _buildRegisterMessage() {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    
    Map<String, dynamic> message = {
      'type': 'register',
      'deviceId': config.deviceId,
      'app': config.app,
      'zone': config.zone,
      'port': config.listenPort,
      'timestamp': timestamp,
    };
    
    if (config.authSecret != null) {
      message['signature'] = _generateSignature(timestamp);
    }
    
    return message;
  }
  
  String _generateSignature(String timestamp) {
    final message = '${config.deviceId}:$timestamp';
    final key = utf8.encode(config.authSecret!);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }
}
```

---

## Checklist для проверки

- [ ] HMAC-аутентификация для WebSocket
- [ ] Rate limiting (10 req/sec)
- [ ] Валидация zone (alphanumeric + _ -)
- [ ] Валидация размера сообщения (64KB)
- [ ] Скрытие IP-адресов пользователей
- [ ] Security headers в nginx
- [ ] TLS для Redis (или localhost only)
- [ ] Аутентификация для billing API
- [ ] Certificate pinning в Flutter
- [ ] Отключение debug логов в release

---

## Мониторинг атак

Добавить логирование подозрительной активности:

```python
# alerts.py
async def log_security_event(event_type: str, details: dict):
    """
    Логирование событий безопасности.
    Интегрировать с alerting системой.
    """
    logger.warning(f"SECURITY: {event_type} - {details}")
    
    # Можно отправлять в:
    # - Sentry
    # - Telegram бот
    # - Email
```

События для мониторинга:
- Неудачные попытки аутентификации
- Подозрительные zone имена
- Превышение rate limit
- Необычно большие сообщения
- Множественные регистрации с одного IP

---

## Заключение

Текущая реализация имеет несколько критических уязвимостей, связанных с отсутствием аутентификации. Рекомендуется:

1. **Немедленно** добавить HMAC-аутентификацию для WebSocket
2. **Немедленно** добавить rate limiting
3. **В ближайшее время** скрыть IP-адреса и добавить security headers
4. **Постепенно** внедрить остальные меры защиты
