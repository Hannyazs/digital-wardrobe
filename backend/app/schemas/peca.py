import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PecaBase(BaseModel):
    categoria: str
    subcategoria: str | None = None
    cor_principal: str | None = None
    estacao: str | None = None
    ocasiao: str | None = None


class PecaCreate(PecaBase):
    imagem_url: str


class PecaRead(PecaBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    usuario_id: uuid.UUID
    imagem_url: str
    criado_em: datetime


class ImagemProcessadaResponse(BaseModel):
    """Resposta do endpoint de pré-processamento: imagem já tratada (rembg)
    mais os metadados sugeridos pela IA, para o usuário revisar antes de
    confirmar o cadastro (POST /pecas)."""

    imagem_url: str
    sugestao: PecaBase
