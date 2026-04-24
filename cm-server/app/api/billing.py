"""
API endpoints для платежей.
Расширяемая архитектура для поддержки нескольких приложений.
Stateless - не использует БД, всё хранится в YooKassa.
"""
import logging
from typing import Optional, Dict, Any

from fastapi import APIRouter, HTTPException

from app.config import settings
from app.services.yookassa_service import (
    create_invoice,
    create_payment_with_redirect,
    get_invoice_status,
    get_payment_status,
    is_payment_successful,
    PaymentError,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================================
# DTO
# ============================================================================

from pydantic import BaseModel, Field


class PaymentCreateRequest(BaseModel):
    """Базовый запрос на создание платежа"""
    device_id: str
    amount: float
    app: str = "progulkin"  # Имя приложения


class PaymentCreateResponse(BaseModel):
    """Ответ на создание платежа"""
    invoice_id: str
    payment_url: str
    amount: float
    expires_in_hours: int = 24


class PaymentStatusResponse(BaseModel):
    """Ответ со статусом платежа"""
    invoice_id: str
    status: str
    amount: float
    currency: str
    is_paid: bool
    device_id: Optional[str] = None
    app: Optional[str] = None
    created_at: Optional[str] = None


# ============================================================================
# ПРОДУКТЫ ПО ПРИЛОЖЕНИЯМ
# ============================================================================

# Конфигурация продуктов для каждого приложения
# Формат: {app_name: {amount: {product_info}}}
APP_PRODUCTS: Dict[str, Dict[int, Dict[str, Any]]] = {
    "progulkin": {
        149: {"name": "Premium", "type": "premium", "features": ["no_ads", "unlimited_walks", "stats"]},
    },
    "starflow": {
        10:  {"energy": 10,  "name": "Разведчик", "type": "energy"},
        25:  {"energy": 30,  "name": "Командир", "type": "energy"},
        79:  {"energy": 100, "name": "Адмирал", "type": "energy"},
    },
    # Добавляйте новые приложения здесь
}


def get_product_info(app: str, amount: float) -> Optional[Dict[str, Any]]:
    """Получить информацию о продукте по приложению и сумме"""
    app_products = APP_PRODUCTS.get(app, {})
    return app_products.get(int(amount))


def build_description(app: str, amount: float, device_id: str) -> str:
    """Строит описание платежа"""
    product = get_product_info(app, amount)

    if app == "progulkin":
        return f"Progulkin Premium для {device_id[:8]}..."
    elif app == "starflow":
        if product:
            return f"Star Flow: {product['name']} ({product['energy']} энергии)"
        return f"Star Flow: {amount}₽ для {device_id[:8]}..."

    # Default
    return f"{app.title()}: {amount}₽ для {device_id[:8]}..."


# ============================================================================
# ENDPOINTS
# ============================================================================

@router.get("/billing/apps")
async def list_apps():
    """Список поддерживаемых приложений"""
    return {
        "apps": [
            {
                "name": name,
                "products": [
                    {"amount": amt, **info}
                    for amt, info in products.items()
                ]
            }
            for name, products in APP_PRODUCTS.items()
        ]
    }


@router.post("/billing/create", response_model=PaymentCreateResponse)
async def create_payment(request: PaymentCreateRequest):
    """
    Создаёт счёт для оплаты.

    - **device_id**: ID устройства (UUID)
    - **amount**: Сумма в рублях
    - **app**: Имя приложения (progulkin, starflow, etc.)

    Возвращает invoice_id и payment_url для оплаты.
    """
    # Проверяем что приложение поддерживается
    if request.app not in APP_PRODUCTS:
        raise HTTPException(
            400,
            f"Приложение '{request.app}' не поддерживается. Доступные: {list(APP_PRODUCTS.keys())}"
        )

    # Валидация суммы
    if request.amount < settings.MIN_PAYMENT_AMOUNT:
        raise HTTPException(
            400,
            f"Минимальная сумма {settings.MIN_PAYMENT_AMOUNT}₽"
        )

    # Проверяем продукт (warning, не error)
    product = get_product_info(request.app, request.amount)
    if not product:
        logger.warning(f"Unknown product: {request.app}/{request.amount}")

    try:
        description = build_description(request.app, request.amount, request.device_id)

        metadata = {
            "type": product.get("type", "unknown") if product else "custom",
        }

        if product and "energy" in product:
            metadata["energy_amount"] = str(product["energy"])

        invoice_id, payment_url = create_invoice(
            amount=request.amount,
            description=description,
            device_id=request.device_id,
            app_name=request.app,
            metadata=metadata,
        )

        logger.info(f"Payment created: {invoice_id} for {request.app}/{request.device_id[:8]}...")

        return PaymentCreateResponse(
            invoice_id=invoice_id,
            payment_url=payment_url,
            amount=request.amount,
        )

    except PaymentError as e:
        logger.error(f"Payment creation failed: {e}")
        raise HTTPException(500, str(e))


@router.post("/billing/create/{app_name}", response_model=PaymentCreateResponse)
async def create_app_payment(app_name: str, request: PaymentCreateRequest):
    """
    Создаёт счёт для конкретного приложения.

    URL: /billing/create/starflow
    """
    request.app = app_name
    return await create_payment(request)


@router.post("/billing/create-starflow", response_model=PaymentCreateResponse)
async def create_starflow_payment(request: PaymentCreateRequest):
    """
    Специализированный endpoint для Star Flow.
    Покупка энергии в игре.
    """
    products = {
        10:  {"energy": 10,  "name": "Разведчик"},
        25:  {"energy": 30,  "name": "Командир"},
        79:  {"energy": 100, "name": "Адмирал"},
    }

    product = products.get(int(request.amount))
    if not product:
        raise HTTPException(400, f"Неверная сумма. Доступные: {list(products.keys())}₽")

    description = f"Star Flow: {product['name']} ({product['energy']} энергии)"

    try:
        # Используем Payment API с редиректом для deep link
        payment_id, payment_url = create_payment_with_redirect(
            amount=request.amount,
            description=description,
            device_id=request.device_id,
            app_name="starflow",
            metadata={
                "type": "starflow_energy",
                "energy_amount": str(product["energy"]),
            }
        )

        logger.info(f"Starflow payment created: {payment_id} for {request.device_id[:8]}...")

        return PaymentCreateResponse(
            invoice_id=payment_id,
            payment_url=payment_url,
            amount=request.amount,
        )

    except PaymentError as e:
        logger.error(f"Starflow payment failed: {e}")
        raise HTTPException(500, str(e))


@router.get("/billing/status/{invoice_id}", response_model=PaymentStatusResponse)
async def check_payment_status(invoice_id: str):
    """
    Проверяет статус оплаты счёта или платежа.

    - **invoice_id**: ID счёта (in-...) или платежа из YooKassa

    Автоматически определяет тип ID:
    - Invoice ID (префикс 'in-'): использует Invoice API
    - Payment ID (без префикса): использует Payment API

    Возвращает текущий статус и информацию о платеже.
    """
    # Определяем тип по формату ID
    is_invoice = invoice_id.startswith("in-")

    try:
        if is_invoice:
            status_info = get_invoice_status(invoice_id)
        else:
            status_info = get_payment_status(invoice_id)

        return PaymentStatusResponse(
            invoice_id=status_info["id"],
            status=status_info["status"],
            amount=status_info["amount"],
            currency=status_info["currency"],
            is_paid=status_info["status"] == "succeeded",
            device_id=status_info.get("metadata", {}).get("device_id"),
            app=status_info.get("metadata", {}).get("app"),
            created_at=status_info.get("created_at"),
        )

    except PaymentError as e:
        logger.error(f"Status check failed for {invoice_id}: {e}")
        raise HTTPException(500, str(e))


@router.get("/billing/check/{invoice_id}")
async def check_is_paid(invoice_id: str):
    """
    Быстрая проверка - оплачен ли счёт или платёж.

    Автоматически определяет тип ID (Invoice или Payment).
    Возвращает только boolean is_paid.
    """
    try:
        is_paid = is_payment_successful(invoice_id)
        return {"invoice_id": invoice_id, "is_paid": is_paid}

    except PaymentError:
        return {"invoice_id": invoice_id, "is_paid": False}


@router.get("/billing/prices")
async def get_prices():
    """Возвращает актуальные цены для всех приложений"""
    return {
        "apps": APP_PRODUCTS,
        "min_amount": settings.MIN_PAYMENT_AMOUNT,
    }
