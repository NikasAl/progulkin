"""
YooKassa Payment Service.
Не сохраняет платежи в БД, использует YooKassa API для проверки статусов.
"""
import logging
import uuid
from typing import Tuple, Dict, Any, Optional

from yookassa import Configuration, Payment

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


def to_iso_string(value) -> Optional[str]:
    """
    Безопасно преобразует дату в ISO строку.
    YooKassa может вернуть строку или datetime объект.
    """
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    return str(value)


def build_return_url(app_name: str) -> str:
    """
    Строит return_url для YooKassa на основе приложения.

    Args:
        app_name: Имя приложения (progulkin, starflow, etc.)

    Returns:
        URL для возврата после оплаты

    Note:
        payment_id не включается в URL - приложение знает его из ответа create.
    """
    scheme = settings.APP_SCHEMES.get(app_name)
    if scheme:
        # Deep link для мобильного приложения
        return f"{scheme}://payment/success"
    else:
        # Fallback на веб
        return f"{settings.BASE_URL}/payment/success"


def create_payment(
    amount: float,
    description: str,
    device_id: str,
    app_name: str = "progulkin",
    metadata: Optional[Dict[str, str]] = None
) -> Tuple[str, str]:
    """
    Создаёт платёж в YooKassa.

    Args:
        amount: Сумма в рублях
        description: Описание платежа
        device_id: ID устройства
        app_name: Имя приложения
        metadata: Дополнительные метаданные

    Returns:
        Tuple[payment_id, confirmation_url]

    Raises:
        PaymentError: Если не удалось создать платёж
    """
    if not settings.YOOKASSA_SHOP_ID or not settings.YOOKASSA_SECRET_KEY:
        raise PaymentError("YooKassa не сконфигурирован")

    try:
        idempotence_key = str(uuid.uuid4())
        return_url = build_return_url(app_name)

        payment_data = {
            "amount": {"value": f"{amount:.2f}", "currency": "RUB"},
            "confirmation": {
                "type": "redirect",
                "return_url": return_url
            },
            "capture": True,
            "description": description,
            "metadata": {
                "device_id": device_id,
                "app": app_name,
                **(metadata or {})
            }
        }

        payment = Payment.create(payment_data, idempotence_key)

        confirmation_url = None
        if payment.confirmation and payment.confirmation.confirmation_url:
            confirmation_url = str(payment.confirmation.confirmation_url)

        if not confirmation_url:
            raise PaymentError("YooKassa не вернула URL для подтверждения")

        logger.info(f"Created payment {payment.id} for {app_name}/{device_id[:8]}... amount={amount}")

        return payment.id, confirmation_url

    except Exception as e:
        logger.error(f"YooKassa Payment Error: {e}")
        raise PaymentError(f"Ошибка создания платежа: {e}")


def get_payment_status(payment_id: str) -> Dict[str, Any]:
    """
    Получает статус платежа из YooKassa.

    Args:
        payment_id: ID платежа в YooKassa

    Returns:
        Dict с информацией о платеже

    Raises:
        PaymentError: Если не удалось получить статус
    """
    if not settings.YOOKASSA_SHOP_ID or not settings.YOOKASSA_SECRET_KEY:
        raise PaymentError("YooKassa не сконфигурирован")

    try:
        payment = Payment.find_one(payment_id)

        result = {
            "id": payment.id,
            "status": payment.status,
            "amount": float(payment.amount.value) if payment.amount else 0,
            "currency": payment.amount.currency if payment.amount else "RUB",
            "created_at": to_iso_string(payment.created_at),
            "metadata": dict(payment.metadata) if payment.metadata else {},
            "description": payment.description,
            "is_paid": payment.status == "succeeded",
        }

        logger.debug(f"Payment {payment_id} status: {payment.status}")
        return result

    except Exception as e:
        logger.error(f"Get Payment Error: {e}")
        raise PaymentError(f"Ошибка получения статуса платежа: {e}")


def is_payment_successful(payment_id: str) -> bool:
    """
    Проверяет, оплачен ли платёж.

    Args:
        payment_id: ID платежа в YooKassa

    Returns:
        True если оплачено, False иначе
    """
    try:
        status = get_payment_status(payment_id)
        return status.get("status") == "succeeded"
    except PaymentError:
        return False
