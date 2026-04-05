# Анализ архитектуры: Сигнальный сервер и Платежи для Progulkin

**Дата:** 2026-04-05

## Текущая инфраструктура

### mindvector (существующий)
- **Стек:** FastAPI + Gunicorn + PostgreSQL
- **Порт:** 8001 (через nginx прокси)
- **Платежи:** YooKassa (Invoices)
- **Аутентификация:** JWT с user_id из БД
- **База данных:** PostgreSQL с таблицами Users, Transactions, UserBalance

### progulkin (текущий)
- **Сигнальный сервер:** Dart TCP на порту 9000
- **Клиенты:** Flutter мобильные приложения
- **Аутентификация:** Device ID (UUID, без серверной БД)

---

## Сравнение вариантов

### Вариант 1: Разместить в mindvector

```
┌─────────────────────────────────────────────────────────────┐
│                      NGINX (443/80)                         │
├─────────────────────────────────────────────────────────────┤
│                         │                                   │
│    /mv/* ◄──────────────┼──────────────► /pg/*              │
│         │               │                   │               │
│         ▼               │                   ▼               │
│  ┌──────────────┐       │          ┌──────────────┐         │
│  │  mindvector  │       │          │ progulkin    │         │
│  │  :8001       │       │          │ endpoints    │         │
│  │              │       │          │ (новые)      │         │
│  │ - billing    │       │          │              │         │
│  │ - users      │       │          │ - /pg/billing│         │
│  │ - concepts   │       │          │ - /pg/status │         │
│  └──────────────┘       │          └──────────────┘         │
│         │               │               │                   │
│         ▼               │               ▼                   │
│  ┌──────────────────────────────────────────────┐          │
│  │              PostgreSQL                      │          │
│  │  (users, transactions для mindvector)        │          │
│  └──────────────────────────────────────────────┘          │
│                                                             │
│  ┌──────────────────────────────────────────────┐          │
│  │        Signaling Server (Dart :9000)         │          │
│  │        TCP socket, stateless                 │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

**Плюсы:**
- ✅ Единая кодовая база для платежей
- ✅ Переиспользование YooKassa интеграции
- ✅ Меньше серверов для мониторинга
- ✅ Общая конфигурация nginx

**Минусы:**
- ❌ Смешивание доменов (mindvector ≠ progulkin)
- ❌ Зависимость от PostgreSQL (для транзакций)
- ❌ Риск повлиять на работающий mindvector
- ❌ Сложнее масштабировать независимо

**Требуемые изменения в mindvector:**
```python
# Новый роутер app/api/v1/progulkin.py
router = APIRouter(prefix="/pg", tags=["progulkin"])

@router.post("/billing/create")
async def create_payment(device_id: str, amount: float):
    # Создаём invoice без записи в БД
    # Возвращаем payment_url и invoice_id
    pass

@router.get("/billing/status/{invoice_id}")
async def check_payment(invoice_id: str):
    # Проверяем статус через YooKassa API
    # НЕ обновляем БД (stateless)
    pass
```

---

### Вариант 2: Отдельный сервер (Рекомендуется)

```
┌─────────────────────────────────────────────────────────────┐
│                      NGINX (443/80)                         │
├─────────────────────────────────────────────────────────────┤
│                         │                                   │
│    /mv/* ◄──────────────┼──────────────► /pg/*              │
│         │               │                   │               │
│         ▼               │                   ▼               │
│  ┌──────────────┐       │          ┌──────────────┐         │
│  │  mindvector  │       │          │ progulkin    │         │
│  │  :8001       │       │          │ :8002        │         │
│  │              │       │          │              │         │
│  │ - billing    │       │          │ - billing    │         │
│  │ - users      │       │          │ - signaling  │         │
│  └──────────────┘       │          └──────────────┘         │
│         │               │               │                   │
│         ▼               │               ▼                   │
│  ┌──────────────┐       │          ┌──────────────┐         │
│  │  PostgreSQL  │       │          │   Redis      │         │
│  │  (mindvector)│       │          │ (кэш статусов│         │
│  └──────────────┘       │          │  платежей)   │         │
│                         │          └──────────────┘         │
│                         │                                   │
│                         │          ┌──────────────┐         │
│                         │          │ Signaling    │         │
│                         │          │ :9000 (TCP)  │         │
│                         │          └──────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

**Плюсы:**
- ✅ Полная изоляция проектов
- ✅ Независимое масштабирование
- ✅ Нет риска сломать mindvector
- ✅ Можно использовать общую YooKassa конфигурацию
- ✅ Stateless архитектура для progulkin

**Минусы:**
- ❌ Дублирование кода YooKassa интеграции
- ❌ Ещё один сервис для мониторинга
- ❌ Дополнительная конфигурация nginx

**Структура проекта progulkin-server:**
```
progulkin-server/
├── app/
│   ├── main.py              # FastAPI приложение
│   ├── config.py            # Настройки (YooKassa, порты)
│   ├── api/
│   │   ├── billing.py       # Stateless платежи
│   │   └── health.py        # Health check
│   └── services/
│       └── yookassa.py      # YooKassa клиент
├── signaling/
│   └── server.py            # TCP сигнальный сервер
├── gunicorn_conf.py
├── requirements.txt
└── Dockerfile
```

---

## Рекомендация: Вариант 2 (Отдельный сервер)

### Обоснование:

1. **Изоляция ответственности**
   - mindvector = образовательная платформа с AI
   - progulkin = трекинг прогулок с P2P
   - Разные домены, разные требования

2. **Stateless vs Stateful**
   - progulkin не требует хранения истории платежей
   - YooKassa сама хранит историю, можно запрашивать по invoice_id
   - Это упрощает архитектуру

3. **Масштабируемость**
   - Сигнальный сервер может потребовать масштабирования отдельно
   - Платежи - лёгкие запросы, не нагружают БД

4. **Безопасность**
   - Ошибка в progulkin не повлияет на mindvector
   - Разные JWT секреты, разные домены

---

## План реализации (Вариант 2)

### Фаза 1: Базовая структура (1 день)

```bash
mkdir -p /home/z/my-project/progulkin-server
cd /home/z/my-project/progulkin-server
```

**requirements.txt:**
```
fastapi>=0.100.0
uvicorn>=0.23.0
yookassa>=3.0.0
pydantic>=2.0.0
python-dotenv>=1.0.0
redis>=4.0.0  # опционально для кэша
```

**app/main.py:**
```python
from fastapi import FastAPI
from app.api import billing, health

app = FastAPI(
    title="Progulkin Server",
    description="Payments and Signaling for Progulkin app",
    version="1.0.0",
)

app.include_router(billing.router, prefix="/pg", tags=["billing"])
app.include_router(health.router, tags=["health"])
```

### Фаза 2: Stateless Billing (1 день)

```python
# app/api/billing.py
from fastapi import APIRouter, HTTPException
from app.services.yookassa import create_invoice, get_invoice_status

router = APIRouter()

@router.post("/billing/create")
async def create_payment(device_id: str, amount: float):
    """
    Создаёт счёт для оплаты.
    НЕ сохраняет в БД - YooKassa хранит историю.
    """
    if amount < 10:
        raise HTTPException(400, "Минимальная сумма 10₽")
    
    description = f"Progulkin Premium для {device_id[:8]}"
    invoice_id, payment_url = create_invoice(amount, description)
    
    return {
        "invoice_id": invoice_id,
        "payment_url": payment_url,
        "amount": amount,
    }

@router.get("/billing/status/{invoice_id}")
async def check_payment(invoice_id: str):
    """
    Проверяет статус оплаты.
    Stateless - запрашивает напрямую у YooKassa.
    """
    status = get_invoice_status(invoice_id)
    return status
```

### Фаза 3: Интеграция с Flutter (1 день)

```dart
// lib/services/payment_service.dart
class PaymentService {
  final String baseUrl = 'https://api.progulkin.ru/pg';
  
  Future<PaymentResult> createPayment(double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/billing/create'),
      body: {
        'device_id': await _getDeviceId(),
        'amount': amount.toString(),
      },
    );
    // ...
  }
  
  Future<PaymentStatus> checkPayment(String invoiceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/billing/status/$invoiceId'),
    );
    // ...
  }
}
```

### Фаза 4: Nginx конфигурация (0.5 дня)

```nginx
# /etc/nginx/sites-available/progulkin
server {
    listen 443 ssl;
    server_name api.progulkin.ru;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # API сервер
    location /pg/ {
        proxy_pass http://127.0.0.1:8002/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Signaling WebSocket (если понадобится)
    location /signaling/ {
        proxy_pass http://127.0.0.1:9000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## Итоговая стоимость

| Компонент | Вариант 1 | Вариант 2 |
|-----------|-----------|-----------|
| Разработка | 1-2 дня | 2-3 дня |
| Риск для mindvector | Высокий | Нет |
| Сложность поддержки | Средняя | Низкая |
| Масштабируемость | Ограничена | Гибкая |
| **Рекомендация** | ❌ | ✅ |

---

## Следующие шаги

1. Создать репозиторий `progulkin-server`
2. Реализовать базовый FastAPI сервер с billing
3. Настроить nginx для `api.progulkin.ru`
4. Интегрировать с Flutter приложением
5. Добавить вебхук от YooKassa для уведомлений об оплате
