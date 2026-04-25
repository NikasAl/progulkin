#!/usr/bin/env python3
"""
Тестовый скрипт для биллинга CM Server.
Использование:
    python test_billing.py                    # Базовый тест (health + apps)
    python test_billing.py --create starflow  # Создать платеж для starflow
    python test_billing.py --status <id>      # Проверить статус платежа
    python test_billing.py --local            # Тестировать локально (localhost:8002)
"""
import argparse
import json
import sys
import uuid

try:
    import requests
except ImportError:
    print("❌ Требуется библиотека requests: pip install requests")
    sys.exit(1)


# Конфигурация по умолчанию
DEFAULT_BASE_URL = "https://kreagenium.ru"
LOCAL_BASE_URL = "http://localhost:8002"


def print_response(response, title="Response"):
    """Красивый вывод ответа"""
    print(f"\n{'='*60}")
    print(f"📋 {title}")
    print(f"{'='*60}")
    print(f"Status: {response.status_code}")

    try:
        data = response.json()
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return data
    except:
        print(response.text)
        return None


def test_health(base_url: str):
    """Тест health endpoint"""
    print("\n" + "="*60)
    print("🏥 Testing Health Endpoints")
    print("="*60)

    # Root
    r = requests.get(f"{base_url}/")
    print_response(r, "GET /")

    # Health
    r = requests.get(f"{base_url}/cm/health")
    print_response(r, "GET /cm/health")


def test_apps(base_url: str):
    """Тест списка приложений"""
    print("\n" + "="*60)
    print("📱 Testing Apps Endpoints")
    print("="*60)

    # Apps list
    r = requests.get(f"{base_url}/cm/billing/apps")
    print_response(r, "GET /cm/billing/apps")

    # Prices
    r = requests.get(f"{base_url}/cm/billing/prices")
    print_response(r, "GET /cm/billing/prices")


def create_payment(base_url: str, app: str, amount: float, device_id: str = None):
    """Создание платежа"""
    if device_id is None:
        device_id = str(uuid.uuid4())

    print("\n" + "="*60)
    print(f"💳 Creating Payment for {app}")
    print("="*60)
    print(f"App: {app}")
    print(f"Amount: {amount}₽")
    print(f"Device ID: {device_id}")

    url = f"{base_url}/cm/billing/create"
    payload = {
        "device_id": device_id,
        "amount": amount,
        "app": app
    }

    r = requests.post(url, json=payload)
    data = print_response(r, f"POST /cm/billing/create")

    if r.status_code == 200 and data:
        print("\n" + "─"*60)
        print("✅ Payment created successfully!")
        print("─"*60)
        print(f"🆔 Payment ID: {data.get('payment_id')}")
        print(f"🔗 Payment URL: {data.get('payment_url')}")
        print(f"💰 Amount: {data.get('amount')}₽")

        return data.get('payment_id'), device_id

    return None, device_id


def check_status(base_url: str, payment_id: str):
    """Проверка статуса платежа"""
    print("\n" + "="*60)
    print(f"🔍 Checking Payment Status")
    print("="*60)
    print(f"Payment ID: {payment_id}")

    # Full status
    r = requests.get(f"{base_url}/cm/billing/status/{payment_id}")
    data = print_response(r, f"GET /cm/billing/status/{payment_id}")

    # Quick check
    r = requests.get(f"{base_url}/cm/billing/check/{payment_id}")
    print_response(r, f"GET /cm/billing/check/{payment_id}")

    if data:
        return data.get('status'), data.get('is_paid')
    return None, None


def main():
    parser = argparse.ArgumentParser(
        description="Тестирование биллинга CM Server",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры:
  %(prog)s                           # Базовый тест
  %(prog)s --local                   # Тест локального сервера
  %(prog)s --create starflow --amount 79  # Создать платеж Star Flow
  %(prog)s --status <payment_id>     # Проверить статус платежа
"""
    )

    parser.add_argument("--local", action="store_true",
                        help="Тестировать локальный сервер (localhost:8002)")
    parser.add_argument("--create", metavar="APP",
                        help="Создать платеж для приложения (progulkin, starflow)")
    parser.add_argument("--amount", type=float, default=79,
                        help="Сумма платежа (по умолчанию 79)")
    parser.add_argument("--status", metavar="PAYMENT_ID",
                        help="Проверить статус платежа")
    parser.add_argument("--device-id", metavar="ID",
                        help="Device ID для платежа")

    args = parser.parse_args()

    # Базовый URL
    base_url = LOCAL_BASE_URL if args.local else DEFAULT_BASE_URL
    print(f"\n🌐 Base URL: {base_url}")

    # Режимы работы
    if args.status:
        # Проверка статуса
        check_status(base_url, args.status)

    elif args.create:
        # Создание платежа
        app = args.create.lower()
        payment_id, device_id = create_payment(base_url, app, args.amount, args.device_id)

        if payment_id:
            print(f"\n💡 Для проверки статуса: python test_billing.py --status {payment_id}")

    else:
        # По умолчанию - базовый тест
        test_health(base_url)
        test_apps(base_url)

        # Предлагаем создать тестовый платеж
        print("\n" + "="*60)
        print("💡 Для создания платежа:")
        print("="*60)
        print(f"  python test_billing.py --create starflow --amount 79")
        print(f"  python test_billing.py --create progulkin --amount 149")


if __name__ == "__main__":
    main()
