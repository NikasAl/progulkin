"""
YooKassa Payment Service - расширяемая реализация для нескольких приложений.
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


def get_app_scheme(app_name: str) -> Optional[str]:
    """Получить URL-схему для приложения"""
    return settings.APP_SCHEMES.get(app_name)


def build_return_url(app_name: str, invoice_id: str) -> str:
    """
    Строит return_url для YooKassa на основе приложения.

    Args:
        app_name: Имя приложения (progulkin, starflow, etc.)
        invoice_id: ID счёта

    Returns:
        URL для возврата после оплаты
    """
    scheme = get_app_scheme(app_name)
    if scheme:
        # Deep link для мобильного приложения
        return f"{scheme}://payment/success?invoice_id={invoice_id}"
    else:
        # Fallback на веб
        return f"{settings.BASE_URL}/payment/success?invoice_id={invoice_id}"


def create_invoice(
    amount: float,
    description: str,
    device_id: str,
    app_name: str = "progulkin",
    metadata: Optional[Dict[str, str]] = None,
    return_url: Optional[str] = None
) -> Tuple[str, str]:
    """
    Создаёт счёт (Invoice) в YooKassa.

    Args:
        amount: Сумма в рублях
        description: Описание платежа
        device_id: ID устройства (для metadata)
        app_name: Имя приложения (progulkin, starflow, etc.)
        metadata: Дополнительные метаданные
        return_url: URL для возврата (если None, генерируется автоматически)

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

        # Генерируем return_url если не передан
        if return_url is None:
            # Временно используем placeholder (обновим после создания invoice)
            return_url = f"{settings.BASE_URL}/payment/pending"

        invoice_data = {
            "payment_data": {
                "amount": {"value": f"{amount:.2f}", "currency": "RUB"},
                "capture": True,
                "description": description,
                "confirmation": {
                    "type": "redirect",
                    "return_url": return_url
                }
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
                "app": app_name,
                **(metadata or {})
            }
        }

        invoice = Invoice.create(invoice_data, idempotence_key)

        payment_url = None
        if invoice.delivery_method and invoice.delivery_method.url:
            payment_url = str(invoice.delivery_method.url)

        if not payment_url:
            raise PaymentError("YooKassa не вернула URL для оплаты")

        logger.info(f"Created invoice {invoice.id} for {app_name}/{device_id[:8]}... amount={amount}")

        return invoice.id, payment_url

    except Exception as e:
        logger.error(f"YooKassa Error: {e}")
        raise PaymentError(f"Ошибка создания счёта: {e}")


def create_payment_with_redirect(
    amount: float,
    description: str,
    device_id: str,
    app_name: str = "progulkin",
    metadata: Optional[Dict[str, str]] = None
) -> Tuple[str, str]:
    """
    Создаёт платеж с редиректом (Payment API вместо Invoice).

    Используется для приложений, которым нужен прямой редирект в приложение
    после оплаты через deep link.

    Args:
        amount: Сумма в рублях
        description: Описание платежа
        device_id: ID устройства
        app_name: Имя приложения
        metadata: Дополнительные метаданные

    Returns:
        Tuple[payment_id, confirmation_url]
    """
    if not settings.YOOKASSA_SHOP_ID or not settings.YOOKASSA_SECRET_KEY:
        raise PaymentError("YooKassa не сконфигурирован")

    try:
        from yookassa import Payment

        idempotence_key = str(uuid.uuid4())

        # Генерируем return_url
        return_url = build_return_url(app_name, "PENDING")  # Будет заменён

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


def get_invoice_status(invoice_id: str) -> Dict[str, Any]:
    """
    Получает статус счёта из YooKassa.

    Args:
        invoice_id: ID счёта в YooKassa

    Returns:
        Dict с информацией о счёте

    Raises:
        PaymentError: Если не удалось получить статус
    """
    if not settings.YOOKASSA_SHOP_ID or not settings.YOOKASSA_SECRET_KEY:
        raise PaymentError("YooKassa не сконфигурирован")

    try:
        invoice = Invoice.find_one(invoice_id)

        # Извлекаем сумму из payment_data или cart
        amount = 0.0
        currency = "RUB"
        
        # payment_data.amount - основной способ
        if hasattr(invoice, 'payment_data') and invoice.payment_data:
            if hasattr(invoice.payment_data, 'amount') and invoice.payment_data.amount:
                amount = float(invoice.payment_data.amount.value)
                currency = getattr(invoice.payment_data.amount, 'currency', 'RUB')
        
        # Fallback: cart[0].price
        if amount == 0.0 and hasattr(invoice, 'cart') and invoice.cart:
            if len(invoice.cart) > 0 and hasattr(invoice.cart[0], 'price'):
                amount = float(invoice.cart[0].price.value)
                currency = getattr(invoice.cart[0].price, 'currency', 'RUB')

        result = {
            "id": invoice.id,
            "status": invoice.status,
            "amount": amount,
            "currency": currency,
            "created_at": to_iso_string(invoice.created_at),
            "expires_at": to_iso_string(invoice.expires_at),
            "metadata": dict(invoice.metadata) if invoice.metadata else {},
            "description": invoice.description,
        }

        logger.debug(f"Invoice {invoice_id} status: {invoice.status}")
        return result

    except Exception as e:
        logger.error(f"Get Invoice Error: {e}")
        raise PaymentError(f"Ошибка получения статуса счёта: {e}")


def get_payment_status(payment_id: str) -> Dict[str, Any]:
    """
    Получает статус платежа из YooKassa.

    Args:
        payment_id: ID платежа в YooKassa

    Returns:
        Dict с информацией о платеже
    """
    if not settings.YOOKASSA_SHOP_ID or not settings.YOOKASSA_SECRET_KEY:
        raise PaymentError("YooKassa не сконфигурирован")

    try:
        from yookassa import Payment

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
    Проверяет, оплачен ли платёж или счёт.

    Автоматически определяет тип ID:
    - Payment ID (без префикса): пробует Payment API
    - Invoice ID (с префиксом 'in-'): пробует Invoice API

    Args:
        payment_id: ID платежа или счёта в YooKassa

    Returns:
        True если оплачено, False иначе
    """
    # Определяем тип по формату ID
    is_invoice = payment_id.startswith("in-")

    if is_invoice:
        # Invoice ID - используем Invoice API
        try:
            status = get_invoice_status(payment_id)
            return status.get("status") == "succeeded"
        except PaymentError:
            return False
    else:
        # Payment ID - используем Payment API
        try:
            status = get_payment_status(payment_id)
            return status.get("status") == "succeeded"
        except PaymentError:
            # Fallback: может это Invoice ID без префикса
            try:
                status = get_invoice_status(payment_id)
                return status.get("status") == "succeeded"
            except PaymentError:
                return False
