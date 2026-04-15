"""
API endpoints для платежей.
Stateless - не использует БД, всё хранится в YooKassa.
"""
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from app.config import settings
from app.services.yookassa_service import (
    create_invoice,
    get_invoice_status,
    PaymentError,
    is_payment_successful
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================================
# DTO
# ============================================================================

from pydantic import BaseModel


class PaymentCreateRequest(BaseModel):
    device_id: str
    amount: float = settings.PREMIUM_PRICE


class PaymentCreateResponse(BaseModel):
    invoice_id: str
    payment_url: str
    amount: float
    expires_in_hours: int = 24


class PaymentStatusResponse(BaseModel):
    invoice_id: str
    status: str
    amount: float
    currency: str
    is_paid: bool
    device_id: Optional[str] = None
    created_at: Optional[str] = None


# ============================================================================
# ENDPOINTS
# ============================================================================

@router.post("/billing/create", response_model=PaymentCreateResponse)
async def create_payment(request: PaymentCreateRequest):
    """
    Создаёт счёт для оплаты Premium.

    - **device_id**: ID устройства (UUID)
    - **amount**: Сумма в рублях (default: 149₽)

    Возвращает invoice_id и payment_url для оплаты.
    """
    # Валидация суммы
    if request.amount < settings.MIN_PAYMENT_AMOUNT:
        raise HTTPException(
            400,
            f"Минимальная сумма {settings.MIN_PAYMENT_AMOUNT}₽"
        )

    try:
        description = f"Progulkin Premium для {request.device_id[:8]}..."

        invoice_id, payment_url = create_invoice(
            amount=request.amount,
            description=description,
            device_id=request.device_id,
            metadata={"type": "premium"}
        )

        logger.info(f"Payment created: {invoice_id} for {request.device_id[:8]}...")

        return PaymentCreateResponse(
            invoice_id=invoice_id,
            payment_url=payment_url,
            amount=request.amount,
        )

    except PaymentError as e:
        logger.error(f"Payment creation failed: {e}")
        raise HTTPException(500, str(e))


@router.get("/billing/status/{invoice_id}", response_model=PaymentStatusResponse)
async def check_payment_status(invoice_id: str):
    """
    Проверяет статус оплаты счёта.

    - **invoice_id**: ID счёта из YooKassa

    Возвращает текущий статус и информацию о счёте.
    """
    try:
        status_info = get_invoice_status(invoice_id)

        return PaymentStatusResponse(
            invoice_id=status_info["id"],
            status=status_info["status"],
            amount=status_info["amount"],
            currency=status_info["currency"],
            is_paid=status_info["status"] == "succeeded",
            device_id=status_info.get("metadata", {}).get("device_id"),
            created_at=status_info.get("created_at"),
        )

    except PaymentError as e:
        logger.error(f"Status check failed for {invoice_id}: {e}")
        raise HTTPException(500, str(e))


@router.get("/billing/check/{invoice_id}")
async def check_is_paid(invoice_id: str):
    """
    Быстрая проверка - оплачен ли счёт.

    Возвращает только boolean is_paid.
    """
    try:
        is_paid = is_payment_successful(invoice_id)
        return {"invoice_id": invoice_id, "is_paid": is_paid}

    except PaymentError:
        return {"invoice_id": invoice_id, "is_paid": False}


@router.get("/billing/prices")
async def get_prices():
    """Возвращает актуальные цены"""
    return {
        "premium": {
            "price": settings.PREMIUM_PRICE,
            "currency": "RUB",
            "features": [
                "Без рекламы",
                "Неограниченные прогулки",
                "Расширенная статистика",
                "Приоритетная поддержка",
            ]
        },
        "min_amount": settings.MIN_PAYMENT_AMOUNT,
    }
