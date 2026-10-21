import uuid

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.peca import PecaRead

# Limite de pares de cores favoritas por usuário (E4.F1.1).
MAX_COMBINACOES_CORES = 20


class CombinacaoCores(BaseModel):
    """Par de cores que o usuário gosta de ver juntas. Sem ordem: (A, B) == (B, A)."""

    cor_a: str
    cor_b: str

    @field_validator("cor_a", "cor_b")
    @classmethod
    def _cor_nao_vazia(cls, valor: str) -> str:
        valor = valor.strip()
        if not valor:
            raise ValueError("A cor não pode ser vazia.")
        return valor

    @model_validator(mode="after")
    def _cores_diferentes(self) -> "CombinacaoCores":
        # Comparação exata (o app só envia nomes de `coresFixas`).
        if self.cor_a == self.cor_b:
            raise ValueError("As duas cores do par precisam ser diferentes.")
        return self


class PreferenciaRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    estilos: list[str]
    sobreposicoes: list[str]
    combinacoes_cores: list[CombinacaoCores]
    criatividade: int


def preferencia_padrao() -> PreferenciaRead:
    """O que `GET /preferencias` devolve enquanto o usuário não salvou nada."""
    return PreferenciaRead(estilos=[], sobreposicoes=[], combinacoes_cores=[], criatividade=3)


def _normalizar_lista(valores: list[str]) -> list[str]:
    # strip, sem vazios nem repetidos, mantendo a ordem.
    vistos: dict[str, None] = {}
    for valor in valores:
        valor = valor.strip()
        if valor:
            vistos.setdefault(valor)
    return list(vistos)


class PreferenciaUpdate(BaseModel):
    # Atualização parcial: o router aplica só o que veio no corpo
    # (`exclude_unset`). Todas as colunas são NOT NULL, então `null` explícito
    # é rejeitado (422), como o `favorito` de `LookUpdate`.
    estilos: list[str] | None = None
    sobreposicoes: list[str] | None = None
    combinacoes_cores: list[CombinacaoCores] | None = None
    criatividade: int | None = Field(default=None, ge=1, le=5)

    @field_validator("estilos", "sobreposicoes", "combinacoes_cores", "criatividade", mode="before")
    @classmethod
    def _nao_nulo(cls, valor):
        if valor is None:
            raise ValueError("O campo não pode ser nulo.")
        return valor

    @field_validator("estilos", "sobreposicoes")
    @classmethod
    def _normaliza_listas(cls, valores: list[str]) -> list[str]:
        return _normalizar_lista(valores)

    @field_validator("combinacoes_cores")
    @classmethod
    def _normaliza_pares(cls, pares: list[CombinacaoCores]) -> list[CombinacaoCores]:
        # Mesmo par em outra ordem conta como repetido; fica o primeiro.
        vistos: dict[frozenset[str], CombinacaoCores] = {}
        for par in pares:
            vistos.setdefault(frozenset((par.cor_a, par.cor_b)), par)
        if len(vistos) > MAX_COMBINACOES_CORES:
            raise ValueError(f"No máximo {MAX_COMBINACOES_CORES} combinações de cores.")
        return list(vistos.values())


# --- E4.F4.1: peças e combinações evitadas ---


class PecaEvitadaCreate(BaseModel):
    peca_id: uuid.UUID


class CombinacaoEvitadaCreate(BaseModel):
    peca_a_id: uuid.UUID
    peca_b_id: uuid.UUID

    @model_validator(mode="after")
    def _pecas_diferentes(self) -> "CombinacaoEvitadaCreate":
        if self.peca_a_id == self.peca_b_id:
            raise ValueError("Uma combinação precisa de duas peças diferentes.")
        return self


class CombinacaoEvitadaRead(BaseModel):
    id: uuid.UUID
    pecas: list[PecaRead]


class EvitadasRead(BaseModel):
    pecas: list[PecaRead]
    combinacoes: list[CombinacaoEvitadaRead]
