import uuid

from pydantic import BaseModel

from app.schemas.peca import PecaRead


class ItemDaSugestaoRead(BaseModel):
    """O que foi achado para uma etiqueta da referência."""

    etiqueta: str
    peca: PecaRead | None = None
    # encontrada | sem_peca_equivalente | nao_entendida | nao_analisada
    situacao: str
    # A peça é do tipo pedido, mas de outra cor que a da etiqueta.
    cor_diferente: bool = False


class LookSalvoRead(BaseModel):
    id: uuid.UUID
    nome: str
    pecas: list[PecaRead]


class SugestaoDeLookRead(BaseModel):
    """Resposta de `POST /referencias/{id}/sugestao-de-look`. Não grava nada.

    `tipo`: `look_salvo` (um look que já existe contém as peças achadas, em
    `look`), `look_novo` (monte um com `pecas`) ou `sem_pecas`. Só peças do
    usuário; `lacunas` são as etiquetas sem equivalente (ou não entendidas).
    """

    tipo: str
    look: LookSalvoRead | None = None
    pecas: list[PecaRead]
    itens: list[ItemDaSugestaoRead]
    lacunas: list[str]
