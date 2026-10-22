import uuid
from datetime import date, datetime, timedelta, timezone

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.peca import PecaRead


def _normalizar_ocasioes(valores: list[str]) -> list[str]:
    # strip, sem vazios nem repetidos, mantendo a ordem. Lista vazia = sem ocasião.
    vistos: dict[str, None] = {}
    for valor in valores:
        valor = valor.strip()
        if valor:
            vistos.setdefault(valor)
    return list(vistos)


class LookCreate(BaseModel):
    nome: str
    peca_ids: list[uuid.UUID] = Field(min_length=1)
    ocasioes: list[str] = []

    _normaliza_ocasioes = field_validator("ocasioes")(_normalizar_ocasioes)


class LookUpdate(BaseModel):
    # Atualização parcial: o router aplica só o que veio no corpo
    # (`exclude_unset`), então campos novos entram aqui.
    nome: str | None = None
    favorito: bool | None = None
    ocasioes: list[str] | None = None
    # E3.F5.2: troca as peças do look (pelo menos uma; o router confere se são do usuário).
    peca_ids: list[uuid.UUID] | None = Field(default=None, min_length=1)

    @field_validator("nome", "favorito", "ocasioes", "peca_ids", mode="before")
    @classmethod
    def _nao_nulo(cls, valor):
        # Colunas NOT NULL: `null` explícito é rejeitado (422) em vez de virar
        # erro de banco. Para limpar as ocasiões, enviar `[]`.
        if valor is None:
            raise ValueError("O campo não pode ser nulo.")
        return valor

    @field_validator("ocasioes")
    @classmethod
    def _normaliza_ocasioes(cls, valores: list[str]) -> list[str]:
        return _normalizar_ocasioes(valores)

    @field_validator("nome")
    @classmethod
    def _nome_preenchido(cls, valor: str) -> str:
        # E5.F3.1: nomes podem repetir, mas não ficar vazios.
        valor = valor.strip()
        if not valor:
            raise ValueError("O nome do look não pode ficar vazio.")
        return valor


class LookRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    usuario_id: uuid.UUID
    nome: str
    favorito: bool
    ocasioes: list[str]
    criado_em: datetime
    pecas: list[PecaRead]


class UsoLookCreate(BaseModel):
    usado_em: date

    @field_validator("usado_em")
    @classmethod
    def _nao_no_futuro(cls, valor: date) -> date:
        # A data vem do app, no fuso do usuário; comparar com "hoje" em UTC
        # rejeitaria um dia legítimo nas primeiras horas do dia seguinte em
        # UTC (ex.: noite no Brasil). Daí a tolerância de +1 dia.
        if valor > datetime.now(timezone.utc).date() + timedelta(days=1):
            raise ValueError("A data de uso não pode estar no futuro.")
        return valor


class UsoLookRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    look_id: uuid.UUID
    usado_em: date
    look: LookRead
