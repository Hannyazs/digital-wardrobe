import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator

NOTA_MAX = 500
ETIQUETA_MAX = 40
ETIQUETAS_MAX = 10


def limpar_nota(nota: str | None) -> str | None:
    """Espaços nas pontas saem; nota vazia vira `None` (sem nota)."""
    if nota is None:
        return None
    nota = nota.strip()
    return nota or None


class LookResumo(BaseModel):
    """O look a que a referência está ligada (E8.F3.1): só o necessário para
    mostrar; as peças o app já tem na lista de looks."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nome: str


class ReferenciaRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    imagem_url: str
    nota: str | None = None
    colecao_id: uuid.UUID | None = None
    look: LookResumo | None = None
    etiquetas: list[str] = []
    criado_em: datetime

    @field_validator("look", mode="before")
    @classmethod
    def _sem_look_arquivado(cls, valor):
        # Excluir um look no app é arquivar: a referência volta a aparecer sem look.
        return None if getattr(valor, "arquivado", False) else valor


class ReferenciaUpdate(BaseModel):
    """Corpo do PATCH /referencias/{id}: só os campos enviados mudam (`nota`
    `colecao_id` e/ou `look_id`; enviar `null` tira a referência da coleção ou do look)."""

    nota: str | None = None
    colecao_id: uuid.UUID | None = None
    look_id: uuid.UUID | None = None
    etiquetas: list[str] | None = None

    @field_validator("etiquetas")
    @classmethod
    def _validar_etiquetas(cls, valor: list[str] | None) -> list[str] | None:
        if valor is None:
            raise ValueError("Envie a lista de etiquetas (vazia para limpar).")
        limpas: list[str] = []
        for etiqueta in valor:
            texto = " ".join(etiqueta.split())
            if not texto or texto.casefold() in {e.casefold() for e in limpas}:
                continue
            if len(texto) > ETIQUETA_MAX:
                raise ValueError(f"Cada etiqueta pode ter no máximo {ETIQUETA_MAX} caracteres.")
            limpas.append(texto)
        if len(limpas) > ETIQUETAS_MAX:
            raise ValueError(f"No máximo {ETIQUETAS_MAX} etiquetas.")
        return limpas

    @field_validator("nota")
    @classmethod
    def _validar_nota(cls, valor: str | None) -> str | None:
        valor = limpar_nota(valor)
        if valor is not None and len(valor) > NOTA_MAX:
            raise ValueError(f"A nota pode ter no máximo {NOTA_MAX} caracteres.")
        return valor
