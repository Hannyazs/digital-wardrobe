import uuid
from datetime import date

from pydantic import BaseModel, Field, field_validator

from app.schemas.peca import PecaRead

MAX_DESCARTADOS = 50


class SugestaoPedido(BaseModel):
    """Corpo de POST /sugestoes (E5.F1.2). Filtros vazios = sem filtro."""

    ocasiao: str | None = None
    estilo: str | None = None
    estacao: str | None = None
    cor: str | None = None
    peca_base_id: uuid.UUID | None = None
    pagina: int = Field(1, ge=1)
    # Looks descartados na sessão, cada um pela lista de ids das suas peças.
    descartados: list[list[uuid.UUID]] = Field(default=[], max_length=MAX_DESCARTADOS)

    @field_validator("ocasiao", "estilo", "estacao", "cor")
    @classmethod
    def _vazio_vira_none(cls, valor: str | None) -> str | None:
        if valor is None:
            return None
        return valor.strip() or None


class LookSugeridoRead(BaseModel):
    pecas: list[PecaRead]
    explicacoes: list[str]
    avisos: list[str]


class ConflitoRead(BaseModel):
    filtro: str
    valor_filtro: str
    valor_peca: str
    mensagem: str


class SugestoesRead(BaseModel):
    looks: list[LookSugeridoRead]
    pagina: int
    tem_mais: bool
    motivo: str | None
    conflitos: list[ConflitoRead]


class LookDoDiaPedido(BaseModel):
    """Corpo de POST /sugestoes/look-do-dia (E6.F1.1)."""

    # Data local do aparelho, como em `POST /looks/{id}/usos`.
    data: date
    # Sem ocasião: usa a salva em `preferencias`, senão "Casual".
    ocasiao: str | None = None
    descartados: list[list[uuid.UUID]] = Field(default=[], max_length=MAX_DESCARTADOS)

    @field_validator("ocasiao")
    @classmethod
    def _vazio_vira_none(cls, valor: str | None) -> str | None:
        if valor is None:
            return None
        return valor.strip() or None


class LookDoDiaRead(BaseModel):
    look: LookSugeridoRead | None
    # E6.F1.3: id do look salvo com exatamente as mesmas peças, se existir.
    look_salvo_id: uuid.UUID | None = None
    ocasiao: str
    tem_mais: bool
    motivo: str | None
