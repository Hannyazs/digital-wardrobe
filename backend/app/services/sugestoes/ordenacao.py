"""Ordenação, páginas e textos (explicações e avisos) dos looks sugeridos.

Ver `docs/regras-sugestoes.md`, seções 5 e 6.
"""

import uuid
from collections import Counter
from collections.abc import Iterable, Mapping
from datetime import date
from itertools import combinations

from app.services.sugestoes.cores import (
    cor_reconhecida,
    cores_nao_neutras,
    eh_neutra,
    ousadia_maxima,
    ousadia_par,
    par_favorito,
)
from app.services.sugestoes.montagem import campos_incompletos
from app.services.sugestoes.tipos import (
    Candidato,
    ContextoRotatividade,
    Filtros,
    PreferenciasMotor,
)

POR_PAGINA = 3
MAX_LOOKS_POR_PECA_NA_PAGINA = 2
DIAS_PARA_ESQUECIDA = 30

ROTULO_OUSADIA = {
    1: "tom sobre tom",
    2: "cores vizinhas",
    3: "cores contrastantes",
    4: "cores opostas",
}


def _estilos_distintos(pecas) -> int:
    """Peças com um estilo em comum contam como um só; sem estilo em comum,
    conta os estilos diferentes que aparecem."""
    com_estilo = [set(p.estilos) for p in pecas if p.estilos]
    if not com_estilo:
        return 0
    return 1 if set.intersection(*com_estilo) else len(set.union(*com_estilo))


def ids_do_look(candidato: Candidato) -> frozenset[uuid.UUID]:
    return frozenset(p.id for p in candidato.pecas)


def eh_esquecida(peca_id: uuid.UUID, contexto: ContextoRotatividade) -> bool:
    """Nunca usada, ou sem uso há mais de 30 dias antes da data de referência."""
    ultimo = contexto.ultimos_usos.get(peca_id)
    return ultimo is None or (contexto.data - ultimo).days > DIAS_PARA_ESQUECIDA


def _criterio_uso(
    pecas, usos: Mapping[uuid.UUID, int], contexto: ContextoRotatividade | None
) -> tuple:
    total = sum(usos.get(p.id, 0) for p in pecas)
    if contexto is None:
        return (total,)  # Épico 5: só o total de usos, como desempate
    # Épico 6: mais peças esquecidas, depois uso mais recente mais antigo, depois total.
    esquecidas = sum(1 for p in pecas if eh_esquecida(p.id, contexto))
    ultimo_do_look = max(
        (contexto.ultimos_usos[p.id] for p in pecas if p.id in contexto.ultimos_usos),
        default=date.min,
    )
    return (-esquecidas, ultimo_do_look.toordinal(), total)


def chave_ordenacao(
    candidato: Candidato,
    prefs: PreferenciasMotor,
    usos: Mapping[uuid.UUID, int],
    contexto: ContextoRotatividade | None = None,
) -> tuple:
    """Menor chave = melhor look. Critérios 1 a 6 e desempate pelos ids."""
    pecas = candidato.pecas
    return (
        -len(candidato.pares_favoritos),  # 1. pares favoritos
        sum(1 for p in pecas if campos_incompletos(p)),  # 2. peças incompletas
        -sum(1 for p in pecas if prefs.estilos.intersection(p.estilos)),  # 3. estilos preferidos
        _estilos_distintos(pecas),  # 4. estilos distintos
        _criterio_uso(pecas, usos, contexto),  # 5. uso (total ou rotatividade)
        ousadia_maxima(prefs.criatividade) - candidato.ousadia,  # 6. distância da ousadia
        tuple(sorted(str(p.id) for p in pecas)),  # desempate final
    )


def ordenar(
    candidatos: Iterable[Candidato],
    prefs: PreferenciasMotor,
    usos: Mapping[uuid.UUID, int],
    contexto: ContextoRotatividade | None = None,
) -> list[Candidato]:
    return sorted(candidatos, key=lambda c: chave_ordenacao(c, prefs, usos, contexto))


def paginar(
    ordenados: list[Candidato],
    pagina: int,
    descartados: Iterable[frozenset[uuid.UUID]] = (),
) -> tuple[list[Candidato], bool]:
    """Página `pagina` (a partir de 1) e se ainda há looks depois dela.

    Cada página pega os melhores looks restantes, pulando os que fariam uma
    peça aparecer mais de 2 vezes nela; os pulados ficam para as próximas.
    """
    descartados = set(descartados)
    restantes = [c for c in ordenados if ids_do_look(c) not in descartados]
    pagina_atual: list[Candidato] = []
    for _ in range(pagina):
        pagina_atual, contagem = [], Counter()
        for candidato in restantes:
            if len(pagina_atual) == POR_PAGINA:
                break
            if all(contagem[p.id] < MAX_LOOKS_POR_PECA_NA_PAGINA for p in candidato.pecas):
                pagina_atual.append(candidato)
                contagem.update(p.id for p in candidato.pecas)
        escolhidos = {id(c) for c in pagina_atual}
        restantes = [c for c in restantes if id(c) not in escolhidos]
    return pagina_atual, bool(restantes)


def explicar(candidato: Candidato, prefs: PreferenciasMotor, filtros: Filtros) -> list[str]:
    """Frases curtas, geradas pelas regras, de por que as peças combinam."""
    frases = []
    pecas = candidato.pecas

    for par in sorted(candidato.pares_favoritos, key=sorted):
        frases.append(f"Usa seu par de cores favorito: {' + '.join(sorted(par))}.")

    cores = cores_nao_neutras(pecas)
    if not cores and any(cor_reconhecida(p) for p in pecas):
        frases.append("Combinação só com cores neutras.")
    elif len(cores) == 1:
        frases.append(f"{next(iter(cores))} com cores neutras.")
    elif len(cores) > 1:
        mais_ousado = None
        for a, b in combinations(pecas, 2):
            if par_favorito(a, b, prefs) or eh_neutra(a) or eh_neutra(b):
                continue
            ousadia = ousadia_par(a, b)
            if ousadia and (mais_ousado is None or ousadia > mais_ousado[0]):
                mais_ousado = (ousadia, cor_reconhecida(a), cor_reconhecida(b))
        if mais_ousado is not None:
            ousadia, cor_a, cor_b = mais_ousado
            frases.append(f"{cor_a} e {cor_b}: {ROTULO_OUSADIA[ousadia]}.")

    # Peças coringa não são tratadas como compatíveis: só afirma o que todas têm.
    if filtros.ocasiao and all(filtros.ocasiao in p.ocasioes for p in pecas):
        frases.append(f"Todas as peças servem para {filtros.ocasiao}.")
    comuns = set.intersection(*(set(p.estilos) for p in pecas)) if pecas else set()
    if comuns:
        frases.append(f"Todas as peças são do estilo {', '.join(sorted(comuns))}.")
    else:
        preferidos = sorted({e for p in pecas for e in p.estilos if e in prefs.estilos})
        if preferidos:
            frases.append(f"Peças no seu estilo preferido: {', '.join(preferidos)}.")
    return frases


def avisos(candidato: Candidato) -> list[str]:
    textos = []
    if candidato.base_evitada:
        textos.append("Você marcou esta peça como evitada.")
    for peca in candidato.pecas:
        faltando = campos_incompletos(peca)
        if faltando:
            textos.append(f"{peca.categoria}: cadastro incompleto (sem {', '.join(faltando)}).")
    if candidato.sem_sapato:
        textos.append("Falta calçado compatível com este look.")
    return textos
