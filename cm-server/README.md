# CM Server (Connection Manager)

Общий сервер для signaling и billing нескольких мобильных приложений.

## Функции

- **Billing** - приём платежей через YooKassa для нескольких приложений
- **Signaling** - сигнальный сервер для P2P соединений (WebRTC)
- **Online Status** - отслеживание онлайн-статуса пользователей

## Поддерживаемые приложения

| Приложение | Описание |
|------------|----------|
| `progulkin` | Прогулкин - прогулочное приложение |
| `starflow` | Star Flow - игровое приложение |

## API Endpoints

### Billing

```
POST /cm/billing/create           # Создать платёж
POST /cm/billing/create/{app}     # Создать платёж для приложения
POST /cm/billing/create-starflow  # Специализированный endpoint для Star Flow
GET  /cm/billing/status/{id}      # Статус платежа
GET  /cm/billing/check/{id}       # Проверка оплаты (boolean)
GET  /cm/billing/prices           # Цены для всех приложений
GET  /cm/billing/apps             # Список приложений
```

### Signaling

```
POST /cm/signal                   # Отправить сигнальное сообщение
POST /cm/session/register         # Зарегистрировать сессию
POST /cm/session/unregister       # Удалить сессию
GET  /cm/online/{app}             # Список онлайн пользователей
GET  /cm/online/{app}/{user_id}   # Проверить онлайн ли пользователь
POST /cm/heartbeat                # Keep-alive для сессии
```

### System

```
GET  /cm/health                   # Health check
GET  /cm/health/ready             # Readiness check (k8s)
```

## Добавление нового приложения

1. Добавьте схему в `config.py`:
```python
APP_SCHEMES: dict = {
    "progulkin": "progulkin",
    "starflow": "starflow",
    "newapp": "newapp",  # <-- добавить
}
```

2. Добавьте продукты в `billing.py`:
```python
APP_PRODUCTS: Dict[str, Dict[int, Dict[str, Any]]] = {
    # ...
    "newapp": {
        99: {"name": "Pro", "type": "subscription"},
    },
}
```

3. (Опционально) Добавьте специализированный endpoint:
```python
@router.post("/billing/create-newapp", response_model=PaymentCreateResponse)
async def create_newapp_payment(request: PaymentCreateRequest):
    # ...
```

## Деплой

```bash
# Синхронизировать файлы
./scripts/deploy.sh sync

# Перезапустить сервер
./scripts/deploy.sh restart

# Полный деплой
./scripts/deploy.sh all

# Логи
./scripts/deploy.sh logs
```

## Nginx Configuration

```nginx
location /cm/ {
    proxy_pass http://127.0.0.1:8002/;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Для signaling (WebSocket)
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Таймауты (стандартные для API)
    proxy_read_timeout 30s;
    proxy_connect_timeout 10s;
    proxy_send_timeout 30s;
}
```

## Локальный запуск

```bash
# Установка зависимостей
pip install -r requirements.txt

# Копируем конфиг
cp .env.example .env
# Отредактируйте .env

# Запуск
python -m app.main
# или
uvicorn app.main:app --reload
```
