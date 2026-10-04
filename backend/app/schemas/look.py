import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.peca import PecaRead


class LookCreate(BaseModel):
    nome: str
    peca_ids: list[uuid.UUID] = Field(min_length=1)


class LookRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    usuario_id: uuid.UUID
    nome: str
    criado_em: datetime
    pecas: list[PecaRead]
