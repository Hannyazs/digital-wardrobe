from fastapi import APIRouter

from app.api.v1 import looks, pecas, preferencias, sugestoes

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(pecas.router)
api_router.include_router(looks.router)
api_router.include_router(preferencias.router)
api_router.include_router(sugestoes.router)
