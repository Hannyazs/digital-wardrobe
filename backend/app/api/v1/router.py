from fastapi import APIRouter

from app.api.v1 import looks, pecas

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(pecas.router)
api_router.include_router(looks.router)
