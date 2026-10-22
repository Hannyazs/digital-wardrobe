"""Ponto de entrada do motor: monta, ordena, pagina e descreve os looks."""

import uuid
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field

from app.services.sugestoes.montagem import LIMITE_PADRAO, gerar_candidatos
from app.services.sugestoes.ordenacao import (
    avisos,
    explicar,
    ids_do_look,
    ordenar,
    paginar,
)
from app.services.sugestoes.tipos import (
    Candidato,
    Conflito,
    ContextoRotatividade,
    Filtros,
    PecaMotor,
    PreferenciasMotor,
    Restricoes,
)

MOTIVO_SEM_MAIS = "Não há mais sugestões com esses filtros."
OCASIAO_PADRAO_LOOK_DO_DIA = "Casual"

_DESCRICAO_CONFLITO = {
    "ocasiao": "Esta peça não está marcada para {filtro} (ocasiões: {peca}).",
    "estilo": "Esta peça é do estilo {peca}, não {filtro}.",
    "estacao": "Esta peça é de {peca}, não de {filtro}.",
}


@dataclass(frozen=True)
class LookSugerido:
    candidato: Candidato
    explicacoes: list[str]
    avisos: list[str]


@dataclass
class ResultadoSugestoes:
    looks: list[LookSugerido] = field(default_factory=list)
    pagina: int = 1
    tem_mais: bool = False
    motivo: str | None = None
    conflitos: list[Conflito] = field(default_factory=list)


def mensagem_conflito(conflito: Conflito) -> str:
    return _DESCRICAO_CONFLITO[conflito.filtro].format(
        filtro=conflito.valor_filtro, peca=conflito.valor_peca
    )


def conjuntos_por_look(
    linhas: Iterable[tuple[uuid.UUID, uuid.UUID]],
) -> list[frozenset[uuid.UUID]]:
    """Linhas (look_id, peca_id) → conjunto de peças de cada look. Usado para
    tratar looks já salvos como descartados (E5.F1.3): só conjunto idêntico
    conta; o mesmo look com uma peça a mais continua podendo ser sugerido."""
    por_look: dict[uuid.UUID, set[uuid.UUID]] = {}
    for look_id, peca_id in linhas:
        por_look.setdefault(look_id, set()).add(peca_id)
    return [frozenset(ids) for ids in por_look.values()]


def sugerir(
    pecas: list[PecaMotor],
    filtros: Filtros,
    prefs: PreferenciasMotor,
    restricoes: Restricoes,
    usos: Mapping[uuid.UUID, int],
    pagina: int = 1,
    descartados: Iterable[frozenset[uuid.UUID]] = (),
    peca_base_id: uuid.UUID | None = None,
    limite: int = LIMITE_PADRAO,
) -> ResultadoSugestoes:
    montagem = gerar_candidatos(pecas, filtros, prefs, restricoes, peca_base_id, limite)
    if not montagem.candidatos:
        return ResultadoSugestoes(
            pagina=pagina, motivo=montagem.motivo, conflitos=montagem.conflitos
        )

    ordenados = ordenar(montagem.candidatos, prefs, usos)
    escolhidos, tem_mais = paginar(ordenados, pagina, descartados)
    looks = [LookSugerido(c, explicar(c, prefs, filtros), avisos(c)) for c in escolhidos]
    return ResultadoSugestoes(
        looks=looks,
        pagina=pagina,
        tem_mais=tem_mais,
        motivo=None if looks else MOTIVO_SEM_MAIS,
    )


def sugerir_look_do_dia(
    pecas: list[PecaMotor],
    ocasiao: str,
    prefs: PreferenciasMotor,
    restricoes: Restricoes,
    usos: Mapping[uuid.UUID, int],
    contexto: ContextoRotatividade,
    descartados: Iterable[frozenset[uuid.UUID]] = (),
    limite: int = LIMITE_PADRAO,
) -> ResultadoSugestoes:
    """Mesmo motor do Épico 5, filtrado pela ocasião e com o critério 5 em modo
    rotatividade. Devolve um único look: o primeiro da ordenação que não foi
    descartado na sessão ("Outra sugestão")."""
    filtros = Filtros(ocasiao=ocasiao)
    montagem = gerar_candidatos(pecas, filtros, prefs, restricoes, None, limite)
    descartados = set(descartados)
    restantes = [
        c
        for c in ordenar(montagem.candidatos, prefs, usos, contexto)
        if ids_do_look(c) not in descartados
    ]
    if not restantes:
        return ResultadoSugestoes(motivo=montagem.motivo or MOTIVO_SEM_MAIS)
    escolhido = restantes[0]
    return ResultadoSugestoes(
        looks=[LookSugerido(escolhido, explicar(escolhido, prefs, filtros), avisos(escolhido))],
        tem_mais=len(restantes) > 1,
    )
