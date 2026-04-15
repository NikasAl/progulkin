# Progulkin Server

API сервер и сигнальный сервер для приложения [Прогулкин](https://github.com/NikasAl/progulkin).

## Компоненты

- **API Server** (FastAPI, порт 8002) - платежи через YooKassa
- **Signaling Server** (TCP, порт 9000) - P2P синхронизация устройств через Redis

## Требования

- Python 3.11+
- Redis (уже установлен в инфраструктуре)
- YooKassa аккаунт для платежей

## Быстрый старт

```bash
# Клонирование
git clone https://github.com/NikasAl/progulkin-server.git
cd progulkin-server

# Виртуальное окружение
python -m venv venv
source venv/bin/activate

# Зависимости
pip install -r requirements.txt

# Конфигурация
cp .env.example .env
# Отредактируйте .env

# Запуск (development)
bash scripts/start.sh

# Или отдельно:
python -m uvicorn app.main:app --reload  # API
python -m signaling.server                # Signaling
```

## API Endpoints

### Billing

| Endpoint | Method | Описание |
|----------|--------|----------|
| `/pg/billing/create` | POST | Создать счёт для оплаты |
| `/pg/billing/status/{invoice_id}` | GET | Проверить статус оплаты |
| `/pg/billing/check/{invoice_id}` | GET | Быстрая проверка (is_paid) |
| `/pg/billing/prices` | GET | Актуальные цены |

### Signaling

| Endpoint | Method | Описание |
|----------|--------|----------|
| `/pg/signaling/stats` | GET | Статистика сервера |
| `/pg/signaling/health` | GET | Health check |
| `/pg/zone/{zone}/devices` | GET | Устройства в зоне |

### System

| Endpoint | Method | Описание |
|----------|--------|----------|
| `/pg/health` | GET | Health check |
| `/pg/` | GET | Информация о сервисе |

## Примеры запросов

### Создание платежа

```bash
curl -X POST http://localhost:8002/pg/billing/create \
  -H "Content-Type: application/json" \
  -d '{"device_id": "abc123", "amount": 149}'
```

Ответ:
```json
{
  "invoice_id": "abc123-456-def",
  "payment_url": "https://yookassa.ru/...",
  "amount": 149,
  "expires_in_hours": 24
}
```

### Проверка статуса

```bash
curl http://localhost:8002/pg/billing/status/abc123-456-def
```

Ответ:
```json
{
  "invoice_id": "abc123-456-def",
  "status": "succeeded",
  "amount": 149,
  "currency": "RUB",
  "is_paid": true,
  "device_id": "abc123"
}
```

## Signaling Protocol

TCP сервер на порту 9000. Все сообщения в JSON, завершаются `\n`.

### Регистрация устройства

```json
{"type": "register", "deviceId": "abc123", "zone": "u4f8d", "port": 9001}
```

Ответ:
```json
{"type": "peers", "zone": "u4f8d", "peers": [...]}
```

### Heartbeat (каждые 60 сек)

```json
{"type": "heartbeat", "deviceId": "abc123"}
```

### Запрос пиров

```json
{"type": "get_peers", "deviceId": "abc123", "zone": "u4f8d"}
```

### Отключение

```json
{"type": "leave", "deviceId": "abc123"}
```

## Деплой

### Systemd

```bash
sudo cp scripts/progulkin-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable progulkin-server
sudo systemctl start progulkin-server
```

### Docker

```bash
docker build -t progulkin-server .
docker run -d -p 8002:8002 -p 9000:9000 --env-file .env progulkin-server
```

### Nginx

```bash
sudo cp scripts/progulkin.nginx /etc/nginx/sites-available/progulkin
sudo ln -s /etc/nginx/sites-available/progulkin /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## Архитектура

```
┌─────────────────────────────────────────────────────┐
│                    NGINX (443)                      │
│                      /pg/*                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│    ┌────────────────────────────────────────────┐   │
│    │           FastAPI (:8002)                  │   │
│    │  - /pg/billing/* (YooKassa)                │   │
│    │  - /pg/signaling/* (stats)                 │   │
│    │  - /pg/health                              │   │
│    └────────────────────────────────────────────┘   │
│                       │                             │
│    ┌──────────────────┴───────────────────────┐     │
│    │                                          │     │
│    ▼                                          ▼     │
│  ┌──────────────┐                    ┌──────────┐   │
│  │    Redis     │◄───────────────────│ Signaling│   │
│  │  (state)     │    TCP :9000       │ Server   │   │
│  └──────────────┘                    └──────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Stateless Design

Сервер **не использует базу данных**:

- Платежи: YooKassa хранит историю, проверяем по API
- Синхронизация: Redis хранит временную информацию о зонах
- Устройства: Авторизация по device_id (UUID)

Это позволяет:
- Горизонтально масштабировать
- Не заботиться о резервном копировании
- Упрощает деплой
