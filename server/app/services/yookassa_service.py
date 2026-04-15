"""
YooKassa Payment Service - Stateless реализация.
Не сохраняет платежи в БД, использует YooKassa API для проверки статусов.
"""
import logging
import uuid
import datetime
from typing import Tuple, Dict, Any, Optional

from yookassa import Configuration, Invoice

from app.config import settings

logger = logging.getLogger(__name__)

# Инициализация YooKassa
if settings.YOOKASSA_SHOP_ID and settings.YOOKASSA_SECRET_KEY:
    Configuration.account_id = settings.YOOKASSA_SHOP_ID
    Configuration.secret_key = settings.YOOKASSA_SECRET_KEY
    logger.info("YooKassa configured successfully")
else:
    logger.warning("YooKassa credentials not configured - payments disabled")


class PaymentError(Exception):
    """Ошибка при работе с платежами"""
    pass


def create_invoice(
    amount: float,
    description: str,
    device_id: str,
    metadata: Optional[Dict[str, str]] = None
) -> Tuple[str, str]:
    """
    Создаёт счёт (Invoice) в YooKassa.

    Args:
        amount: Сумма в рублях
        description: Описание платежа
        device_id: ID устройства (для metadata)
        metadata: Дополнительные метаданные

    Returns:
        Tuple[invoice_id, payment_url]

    Raises:
        PaymentError: Если не удалось создать счёт
    """
    if not settings.YOOKASSA_SHOP_ID or not settings.YOOKASSA_SECRET_KEY:
        raise PaymentError("YooKassa не сконфигурирован")

    try:
        # Срок действия счёта - 24 часа
        expires_at = (
            datetime.datetime.now(datetime.timezone.utc) + 
            datetime.timedelta(hours=24)
        ).strftime("%Y-%m-%dT%H:%M:%SZ")

        idempotence_key = str(uuid.uuid4())

        invoice_data = {
            "payment_data": {
                "amount": {"value": f"{amount:.2f}", "currency": "RUB"},
                "capture": True,
                "description": description
            },
            "cart": [{
                "description": description,
                "price": {"value": f"{amount:.2f}", "currency": "RUB"},
                "quantity": 1.0
            }],
            "delivery_method_data": {"type": "self"},
            "expires_at": expires_at,
            "description": description,
            "metadata": {
                "device_id": device_id,
                "app": "progulkin",
                **(metadata or {})
            }
        }

        invoice = Invoice.create(invoice_data, idempotence_key)

        payment_url = None
        if invoice.delivery_method and invoice.delivery_method.url:
            payment_url = str(invoice.delivery_method.url)

        if not payment_url:
            raise PaymentError("YooKassa не вернула URL для оплаты")

        logger.info(f"Created invoice {invoice.id} for device {device_id[:8]}... amount={amount}")

        return invoice.id, payment_url

    except Exception as e:
        logger.error(f"YooKassa Error: {e}")
        raise PaymentError(f"Ошибка создания счёта: {e}")


def get_invoice_status(invoice_id: str) -> Dict[str, Any]:
    """
    Получает статус счёта из YooKassa.

    Args:
        invoice_id: ID счёта в YooKassa

    Returns:
        Dict с информацией о счёте:
        - id: ID счёта
        - status: pending/succeeded/canceled
        - amount: сумма
        - metadata: метаданные (включая device_id)

    Raises:
        PaymentError: Если не удалось получить статус
    """
    if not settings.YOOKASSA_SHOP_ID or not settings.YOOKASSA_SECRET_KEY:
        raise PaymentError("YooKassa не сконфигурирован")

    try:
        invoice = Invoice.find_one(invoice_id)

        result = {
            "id": invoice.id,
            "status": invoice.status,
            "amount": float(invoice.amount.value) if invoice.amount else 0,
            "currency": invoice.amount.currency if invoice.amount else "RUB",
            "created_at": invoice.created_at.isoformat() if invoice.created_at else None,
            "expires_at": invoice.expires_at.isoformat() if invoice.expires_at else None,
            "metadata": dict(invoice.metadata) if invoice.metadata else {},
            "description": invoice.description,
        }

        logger.debug(f"Invoice {invoice_id} status: {invoice.status}")
        return result

    except Exception as e:
        logger.error(f"Get Invoice Error: {e}")
        raise PaymentError(f"Ошибка получения статуса счёта: {e}")


def is_payment_successful(invoice_id: str) -> bool:
    """
    Проверяет, оплачен ли счёт.

    Args:
        invoice_id: ID счёта в YooKassa

    Returns:
        True если счёт оплачен, False иначе
    """
    try:
        status = get_invoice_status(invoice_id)
        return status.get("status") == "succeeded"
    except PaymentError:
        return False
