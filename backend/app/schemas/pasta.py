import uuid
from datetime import datetime

from pydantic import BaseModel, field_validator

NOME_MAX = 40


class PastaWrite(BaseModel):
    """Corpo do POST /pastas e do PATCH /pastas/{id} (renomear) (E3.F6.1)."""

    nome: str

    @field_validator("nome")
    @classmethod
    def _validar_nome(cls, valor: str) -> str:
        valor = valor.strip()
        if not valor:
            raise ValueError("Dê um nome à pasta.")
        if len(valor) > NOME_MAX:
            raise ValueError(f"O nome pode ter no máximo {NOME_MAX} caracteres.")
        return valor


class PastaRead(BaseModel):
    id: uuid.UUID
    nome: str
    # Só looks não arquivados (E3.F5.1).
    quantidade: int
    criado_em: datetime
