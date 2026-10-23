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
MOTIVO_TODOS_SALVOS = (
    "Todas as combinações possíveis já estão nos seus looks salvos. "
    "Cadastre mais peças ou mude os filtros."
)
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


def looks_por_conjunto(
    linhas: Iterable[tuple[uuid.UUID, uuid.UUID]],
) -> dict[frozenset[uuid.UUID], uuid.UUID]:
    """Linhas (look_id, peca_id) → {conjunto de peças: id do look}. Os conjuntos
    são os looks salvos que a aba Sugestões não repete (E5.F1.3; só conjunto
    idêntico conta) e o id diz ao look do dia qual look já existe (E6.F1.3).
    Se dois looks tiverem as mesmas peças, fica o primeiro das linhas."""
    por_look: dict[uuid.UUID, set[uuid.UUID]] = {}
    for look_id, peca_id in linhas:
        por_look.setdefault(look_id, set()).add(peca_id)
    resultado: dict[frozenset[uuid.UUID], uuid.UUID] = {}
    for look_id, ids in por_look.items():
        resultado.setdefault(frozenset(ids), look_id)
    return resultado


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
    salvos: Iterable[frozenset[uuid.UUID]] = (),
) -> ResultadoSugestoes:
    """`salvos` (looks já salvos, E5.F1.3) ficam de fora como os descartes; a
    diferença é só a mensagem quando eles são o motivo da lista vazia."""
    montagem = gerar_candidatos(pecas, filtros, prefs, restricoes, peca_base_id, limite)
    if not montagem.candidatos:
        return ResultadoSugestoes(
            pagina=pagina, motivo=montagem.motivo, conflitos=montagem.conflitos
        )

    descartados, salvos = list(descartados), list(salvos)
    ordenados = ordenar(montagem.candidatos, prefs, usos)
    escolhidos, tem_mais = paginar(ordenados, pagina, descartados + salvos)
    looks = [LookSugerido(c, explicar(c, prefs, filtros), avisos(c)) for c in escolhidos]
    motivo = None
    if not looks:
        # Na 1ª página, se só os looks salvos esvaziaram a lista, diz isso em
        # vez de "não há mais" (que parece que algo já foi mostrado).
        so_salvos = pagina == 1 and salvos and paginar(ordenados, 1, descartados)[0]
        motivo = MOTIVO_TODOS_SALVOS if so_salvos else MOTIVO_SEM_MAIS
    return ResultadoSugestoes(looks=looks, pagina=pagina, tem_mais=tem_mais, motivo=motivo)


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
