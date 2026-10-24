import uuid
from datetime import datetime

from pydantic import BaseModel, field_validator

NOME_MAX = 40


class ColecaoWrite(BaseModel):
    """Corpo do POST /colecoes e do PATCH /colecoes/{id} (renomear)."""

    nome: str

    @field_validator("nome")
    @classmethod
    def _validar_nome(cls, valor: str) -> str:
        valor = valor.strip()
        if not valor:
            raise ValueError("Dê um nome à coleção.")
        if len(valor) > NOME_MAX:
            raise ValueError(f"O nome pode ter no máximo {NOME_MAX} caracteres.")
        return valor


class ColecaoRead(BaseModel):
    id: uuid.UUID
    nome: str
    quantidade: int
    criado_em: datetime
