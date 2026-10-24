"""Sugestão de look a partir de uma referência (E8.F5.2): o funil da E8.F5.1 +
a comparação visual, uma etiqueta por vez.

A orquestração é pura: as fotos, a comparação (`escolher`) e o relógio entram
por parâmetro, então os testes não dependem do Ollama nem do disco. A regra do
produto vale em tudo: só peças do usuário, e o que não tem equivalente é
lacuna explícita.
"""

import time
import uuid
from collections.abc import Callable, Collection, Mapping, Sequence
from dataclasses import dataclass

from app.services.inspiracao.candidatos import MOTIVO_NAO_ENTENDIDA, PecaCandidata, estreitar

MAX_ETIQUETAS_ANALISADAS = 6

TIPO_LOOK_SALVO = "look_salvo"
TIPO_LOOK_NOVO = "look_novo"
TIPO_SEM_PECAS = "sem_pecas"

SITUACAO_ENCONTRADA = "encontrada"
SITUACAO_SEM_EQUIVALENTE = "sem_peca_equivalente"
SITUACAO_NAO_ENTENDIDA = "nao_entendida"
SITUACAO_NAO_ANALISADA = "nao_analisada"


@dataclass(frozen=True)
class ItemSugestao:
    etiqueta: str
    peca_id: uuid.UUID | None
    situacao: str
    # A peça achada é do tipo certo, mas de outra cor que a da etiqueta.
    cor_diferente: bool = False


@dataclass(frozen=True)
class ResultadoSugestao:
    tipo: str
    itens: tuple[ItemSugestao, ...]
    pecas_ids: tuple[uuid.UUID, ...]
    look_id: uuid.UUID | None = None

    @property
    def lacunas(self) -> tuple[str, ...]:
        """Etiquetas sem peça equivalente ou que não foram entendidas. As que
        ficaram sem análise (tempo esgotado) aparecem só em `itens`."""
        return tuple(
            i.etiqueta
            for i in self.itens
            if i.situacao in (SITUACAO_SEM_EQUIVALENTE, SITUACAO_NAO_ENTENDIDA)
        )


def _look_que_contem(
    escolhidas: Collection[uuid.UUID], looks_salvos: Mapping[uuid.UUID, Collection[uuid.UUID]]
) -> uuid.UUID | None:
    """Look salvo que tem todas as peças escolhidas; o de menos peças a mais,
    e o `id` menor no empate."""
    servem = [
        (len(pecas) - len(escolhidas), str(look_id), look_id)
        for look_id, pecas in looks_salvos.items()
        if set(escolhidas) <= set(pecas)
    ]
    return min(servem)[2] if servem else None


def sugerir_look(
    etiquetas: Sequence[str],
    pecas: Sequence[PecaCandidata],
    evitadas: Collection[uuid.UUID],
    looks_salvos: Mapping[uuid.UUID, Collection[uuid.UUID]],
    imagem_referencia: bytes,
    ler_imagem: Callable[[uuid.UUID], bytes],
    escolher: Callable[[bytes, str, list[bytes]], int | None],
    tempo_max_s: float,
    relogio: Callable[[], float] = time.monotonic,
) -> ResultadoSugestao:
    inicio = relogio()
    analisadas = list(etiquetas[:MAX_ETIQUETAS_ANALISADAS])
    funis = estreitar(analisadas, pecas, evitadas)
    cores_por_peca = {p.id: p.cores for p in pecas}

    itens: list[ItemSugestao] = []
    escolhidas: list[uuid.UUID] = []
    for funil in funis:
        if funil.categoria is None:
            itens.append(ItemSugestao(funil.etiqueta, None, SITUACAO_NAO_ENTENDIDA))
            continue
        # Uma peça não vale por duas etiquetas: as já escolhidas saem da disputa.
        candidatas = [i for i in funil.candidatas if i not in escolhidas]
        fotos: list[tuple[uuid.UUID, bytes]] = []
        for peca_id in candidatas:
            try:
                fotos.append((peca_id, ler_imagem(peca_id)))
            except OSError:
                continue  # foto sumiu do disco: essa candidata não pode ser comparada
        if not fotos:
            itens.append(ItemSugestao(funil.etiqueta, None, SITUACAO_SEM_EQUIVALENTE))
            continue
        if relogio() - inicio >= tempo_max_s:
            itens.append(ItemSugestao(funil.etiqueta, None, SITUACAO_NAO_ANALISADA))
            continue
        try:
            indice = escolher(imagem_referencia, funil.etiqueta, [foto for _, foto in fotos])
        except Exception:  # a IA nunca derruba a sugestão: a etiqueta fica sem equivalente
            indice = None
        if indice is None or not 0 <= indice < len(fotos):
            itens.append(ItemSugestao(funil.etiqueta, None, SITUACAO_SEM_EQUIVALENTE))
            continue
        escolhida = fotos[indice][0]
        escolhidas.append(escolhida)
        cores_da_peca = cores_por_peca.get(escolhida, frozenset())
        cor_diferente = bool(funil.cores and cores_da_peca and not set(funil.cores) & cores_da_peca)
        itens.append(ItemSugestao(funil.etiqueta, escolhida, SITUACAO_ENCONTRADA, cor_diferente))

    # Etiquetas além do limite não foram olhadas.
    itens.extend(ItemSugestao(e, None, SITUACAO_NAO_ANALISADA) for e in etiquetas[MAX_ETIQUETAS_ANALISADAS:])

    if not escolhidas:
        return ResultadoSugestao(TIPO_SEM_PECAS, tuple(itens), ())
    look_id = _look_que_contem(escolhidas, looks_salvos) if len(escolhidas) >= 2 else None
    tipo = TIPO_LOOK_SALVO if look_id is not None else TIPO_LOOK_NOVO
    return ResultadoSugestao(tipo, tuple(itens), tuple(escolhidas), look_id)


__all__ = ["MOTIVO_NAO_ENTENDIDA", "ResultadoSugestao", "ItemSugestao", "sugerir_look"]
