"""
Health check endpoint.
"""
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check():
    """Проверка работоспособности сервера"""
    return {
        "status": "healthy",
        "service": "cm-server",
    }


@router.get("/health/ready")
async def readiness_check():
    """Проверка готовности сервера (для k8s)"""
    return {"status": "ready"}
