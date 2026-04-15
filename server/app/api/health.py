"""
Health check и системные endpoints.
"""
from fastapi import APIRouter

from app.config import settings

router = APIRouter()


@router.get("/health")
async def health_check():
    """Health check для балансировщика нагрузки"""
    return {
        "status": "ok",
        "service": "progulkin-server",
        "env": settings.ENV,
    }


@router.get("/")
async def root():
    """Корневой endpoint"""
    return {
        "service": "Progulkin Server",
        "version": "1.0.0",
        "endpoints": {
            "billing": "/pg/billing",
            "signaling": "/pg/signaling",
            "health": "/pg/health",
        }
    }
