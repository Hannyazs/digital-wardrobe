import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PecaBase(BaseModel):
    categoria: str
    subcategoria: str | None = None
    cor_principal: str | None = None
    estacao: str | None = None
    tonalidade_cor: str | None = None
    estilo: str | None = None
    modelagem: str | None = None
    ocasioes: list[str] = []


class PecaCreate(PecaBase):
    imagem_url: str


class PecaUpdate(PecaBase):
    """Payload de PUT /pecas/{id} (E1.F3.1) — mesmos campos de PecaBase,
    nunca imagem_url: a foto da peça é imutável após o cadastro."""


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


class ImagemOriginalResponse(BaseModel):
    """Resposta do fallback de upload sem processamento (E1.F1.4): usado
    quando /processar-imagem falhou e o usuário optou por continuar sem
    remoção de fundo."""

    imagem_url: str
