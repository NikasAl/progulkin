"""
API endpoints для сигнального сервера.
Используется для P2P соединений между пользователями.
"""
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException

from app.services.redis_service import redis_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================================
# DTO
# ============================================================================

from pydantic import BaseModel


class SignalMessage(BaseModel):
    """Сообщение для сигнализации"""
    from_user: str
    to_user: str
    type: str  # offer, answer, ice-candidate
    data: dict
    app: str = "progulkin"


class OnlineStatusRequest(BaseModel):
    """Запрос на обновление статуса онлайн"""
    user_id: str
    app: str = "progulkin"


class UserSessionRequest(BaseModel):
    """Запрос на регистрацию сессии"""
    user_id: str
    app: str = "progulkin"
    device_id: Optional[str] = None


# ============================================================================
# SIGNALING ENDPOINTS
# ============================================================================

@router.post("/signal")
async def send_signal(message: SignalMessage):
    """
    Отправить сигнальное сообщение другому пользователю.

    Используется для WebRTC signalling (offer, answer, ice-candidate).
    Сообщение публикуется в Redis канал пользователя-получателя.
    """
    try:
        import json

        # Публикуем в канал пользователя
        channel = f"signal:{message.app}:{message.to_user}"
        payload = json.dumps({
            "from": message.from_user,
            "type": message.type,
            "data": message.data,
        })

        await redis_service.publish(channel, payload)

        return {"status": "sent", "channel": channel}

    except Exception as e:
        logger.error(f"Signal send failed: {e}")
        raise HTTPException(500, f"Ошибка отправки сигнала: {e}")


@router.post("/session/register")
async def register_session(request: UserSessionRequest):
    """
    Зарегистрировать сессию пользователя.

    Помечает пользователя как онлайн для данного приложения.
    """
    try:
        # Сохраняем сессию в Redis с TTL 5 минут
        session_key = f"session:{request.app}:{request.user_id}"

        await redis_service.hset(session_key, "status", "online")
        if request.device_id:
            await redis_service.hset(session_key, "device_id", request.device_id)
        await redis_service.expire(session_key, 300)  # 5 минут TTL

        # Добавляем в список онлайн
        await redis_service.add_online_user(request.app, request.user_id, ttl=300)

        return {"status": "registered", "user_id": request.user_id}

    except Exception as e:
        logger.error(f"Session registration failed: {e}")
        raise HTTPException(500, f"Ошибка регистрации сессии: {e}")


@router.post("/session/unregister")
async def unregister_session(request: UserSessionRequest):
    """
    Удалить сессию пользователя.

    Помечает пользователя как офлайн.
    """
    try:
        session_key = f"session:{request.app}:{request.user_id}"
        await redis_service.delete(session_key)
        await redis_service.remove_online_user(request.app, request.user_id)

        return {"status": "unregistered", "user_id": request.user_id}

    except Exception as e:
        logger.error(f"Session unregistration failed: {e}")
        raise HTTPException(500, f"Ошибка удаления сессии: {e}")


@router.get("/online/{app}")
async def get_online_users(app: str):
    """
    Получить список онлайн пользователей для приложения.
    """
    try:
        users = await redis_service.get_online_users(app)
        return {"app": app, "online_count": len(users), "users": users}

    except Exception as e:
        logger.error(f"Get online users failed: {e}")
        raise HTTPException(500, f"Ошибка получения списка: {e}")


@router.get("/online/{app}/{user_id}")
async def check_user_online(app: str, user_id: str):
    """
    Проверить онлайн ли конкретный пользователь.
    """
    try:
        is_online = await redis_service.is_user_online(app, user_id)
        return {"user_id": user_id, "is_online": is_online}

    except Exception as e:
        logger.error(f"Check online failed: {e}")
        raise HTTPException(500, f"Ошибка проверки статуса: {e}")


@router.post("/heartbeat")
async def heartbeat(request: OnlineStatusRequest):
    """
    Обновить статус онлайн (keep-alive).

    Клиент должен вызывать каждые 2-3 минуты.
    """
    try:
        # Продлеваем TTL сессии
        session_key = f"session:{request.app}:{request.user_id}"

        if await redis_service.exists(session_key):
            await redis_service.expire(session_key, 300)
            await redis_service.add_online_user(request.app, request.user_id, ttl=300)
            return {"status": "ok", "ttl": 300}
        else:
            # Сессия истекла, нужно зарегистрировать заново
            return {"status": "expired", "ttl": 0}

    except Exception as e:
        logger.error(f"Heartbeat failed: {e}")
        raise HTTPException(500, f"Ошибка heartbeat: {e}")
