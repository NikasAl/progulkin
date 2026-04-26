"""
API роутер - объединяет все endpoints.
"""
from fastapi import APIRouter

from app.api import billing, signaling, signaling_ws, health

api_router = APIRouter()

api_router.include_router(health.router, tags=["system"])
api_router.include_router(billing.router, tags=["billing"])
api_router.include_router(signaling.router, tags=["signaling"])
api_router.include_router(signaling_ws.router, tags=["signaling-ws"])
