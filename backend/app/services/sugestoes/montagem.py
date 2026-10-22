"""Montagem dos looks candidatos: estrutura, filtros, restrições e coringas.

Ver `docs/regras-sugestoes.md`, seções 2 a 4 e 6 (limite de candidatos).
Combinações inválidas são descartadas a cada peça adicionada, para o número
de candidatos não crescer à toa.
"""

import uuid

from app.services.sugestoes.cores import (
    MAX_CORES_NAO_NEUTRAS,
    avaliar_cores,
    cor_reconhecida,
    cores_nao_neutras,
    par_permitido,
)
from app.services.sugestoes.tipos import (
    CASACOS,
    ESTACAO_TODAS,
    ESTACOES_COM_CASACO,
    PARTES_DE_BAIXO,
    PARTES_DE_CIMA,
    SAPATOS,
    VESTIDOS,
    Candidato,
    Conflito,
    Filtros,
    PecaMotor,
    PreferenciasMotor,
    ResultadoMontagem,
    Restricoes,
)

LIMITE_PADRAO = 20_000
MAX_CORINGAS = 1

MOTIVO_ARMARIO_VAZIO = "Seu armário ainda não tem peças cadastradas."
MOTIVO_ACESSORIO = "Acessórios ainda não entram nas sugestões."


def campos_incompletos(peca: PecaMotor) -> list[str]:
    """Campos que deixam a peça com cadastro incompleto (estação não conta)."""
    faltando = []
    if cor_reconhecida(peca) is None:
        faltando.append("cor")
    if not peca.ocasioes:
        faltando.append("ocasião")
    if not (peca.estilo or "").strip():
        faltando.append("estilo")
    return faltando


def eh_coringa(peca: PecaMotor, filtros: Filtros) -> bool:
    """Falta um campo que este pedido usa: cor sempre; ocasião/estilo só com filtro."""
    if cor_reconhecida(peca) is None:
        return True
    if filtros.ocasiao and not peca.ocasioes:
        return True
    if filtros.estilo and not (peca.estilo or "").strip():
        return True
    return False


def _atende_filtros(peca: PecaMotor, filtros: Filtros) -> bool:
    """Filtros por peça. Campo vazio passa (vira coringa ou estação livre)."""
    if filtros.ocasiao and peca.ocasioes and filtros.ocasiao not in peca.ocasioes:
        return False
    estilo = (peca.estilo or "").strip()
    if filtros.estilo and estilo and estilo != filtros.estilo:
        return False
    estacao = (peca.estacao or "").strip()
    if (
        filtros.estacao
        and estacao
        and estacao != ESTACAO_TODAS
        and estacao != filtros.estacao
    ):
        return False
    return True


def conflitos_da_base(base: PecaMotor, filtros: Filtros) -> list[Conflito]:
    conflitos = []
    if filtros.ocasiao and base.ocasioes and filtros.ocasiao not in base.ocasioes:
        conflitos.append(Conflito("ocasiao", filtros.ocasiao, ", ".join(base.ocasioes)))
    estilo = (base.estilo or "").strip()
    if filtros.estilo and estilo and estilo != filtros.estilo:
        conflitos.append(Conflito("estilo", filtros.estilo, estilo))
    estacao = (base.estacao or "").strip()
    if filtros.estacao and estacao and estacao not in (ESTACAO_TODAS, filtros.estacao):
        conflitos.append(Conflito("estacao", filtros.estacao, estacao))
    return conflitos


def _pode_adicionar(
    parcial: tuple[PecaMotor, ...],
    peca: PecaMotor,
    filtros: Filtros,
    prefs: PreferenciasMotor,
    restricoes: Restricoes,
) -> bool:
    for outra in parcial:
        if frozenset({outra.id, peca.id}) in restricoes.pares_evitados:
            return False
        if not par_permitido(outra, peca, prefs):
            return False
    novo = parcial + (peca,)
    if sum(eh_coringa(p, filtros) for p in novo) > MAX_CORINGAS:
        return False
    return len(cores_nao_neutras(novo)) <= MAX_CORES_NAO_NEUTRAS


def _ordenadas(pecas: list[PecaMotor]) -> list[PecaMotor]:
    # Ordem estável e independente da ordem de entrada (resultado determinístico).
    return sorted(pecas, key=lambda p: str(p.id))


def gerar_candidatos(
    pecas: list[PecaMotor],
    filtros: Filtros,
    prefs: PreferenciasMotor,
    restricoes: Restricoes,
    peca_base_id: uuid.UUID | None = None,
    limite: int = LIMITE_PADRAO,
) -> ResultadoMontagem:
    if not pecas:
        return ResultadoMontagem(motivo=MOTIVO_ARMARIO_VAZIO)

    base: PecaMotor | None = None
    if peca_base_id is not None:
        base = next((p for p in pecas if p.id == peca_base_id), None)
        if base is None:
            raise ValueError("Peça-base não está entre as peças do usuário.")
        slots_conhecidos = PARTES_DE_CIMA | PARTES_DE_BAIXO | VESTIDOS | SAPATOS | CASACOS
        if base.categoria not in slots_conhecidos:
            return ResultadoMontagem(motivo=MOTIVO_ACESSORIO)
        conflitos = conflitos_da_base(base, filtros)
        if conflitos:
            return ResultadoMontagem(conflitos=conflitos)

    def elegiveis(categorias: frozenset[str]) -> list[PecaMotor]:
        if base is not None and base.categoria in categorias:
            return [base]
        return _ordenadas(
            [
                p
                for p in pecas
                if p.categoria in categorias
                and p.id not in restricoes.pecas_evitadas
                and _atende_filtros(p, filtros)
            ]
        )

    cimas = elegiveis(PARTES_DE_CIMA)
    baixos = elegiveis(PARTES_DE_BAIXO)
    vestidos = elegiveis(VESTIDOS)
    sapatos = elegiveis(SAPATOS)
    casacos = elegiveis(CASACOS)

    # Peça-base de uma categoria exclui as estruturas que não a usam.
    if base is not None and base.categoria in VESTIDOS:
        cimas, baixos = [], []
    if base is not None and base.categoria in PARTES_DE_CIMA | PARTES_DE_BAIXO:
        vestidos = []

    base_casaco = base is not None and base.categoria in CASACOS
    incluir_casaco = (
        base_casaco or filtros.estacao in ESTACOES_COM_CASACO or bool(prefs.sobreposicoes)
    )
    base_evitada = base is not None and base.id in restricoes.pecas_evitadas

    resultado = ResultadoMontagem()

    def bases_do_look():
        for cima in cimas:
            for baixo in baixos:
                if _pode_adicionar((cima,), baixo, filtros, prefs, restricoes):
                    yield (cima, baixo)
        for vestido in vestidos:
            if _pode_adicionar((), vestido, filtros, prefs, restricoes):
                yield (vestido,)

    def registrar(pecas_look: tuple[PecaMotor, ...], sem_sapato: bool) -> bool:
        """Avalia um look completo; devolve False quando o limite foi atingido."""
        if len(resultado.candidatos) >= limite:
            resultado.limite_atingido = True
            return False
        if filtros.cor and not any((p.cor or "").strip() == filtros.cor for p in pecas_look):
            return True
        valido, ousadia, favoritos = avaliar_cores(pecas_look, prefs)
        if not valido:
            return True
        resultado.candidatos.append(
            Candidato(
                pecas=pecas_look,
                ousadia=ousadia,
                pares_favoritos=favoritos,
                coringas=frozenset(p.id for p in pecas_look if eh_coringa(p, filtros)),
                sem_sapato=sem_sapato,
                base_evitada=base_evitada,
            )
        )
        return True

    for parcial in bases_do_look():
        com_sapato = [
            parcial + (sapato,)
            for sapato in sapatos
            if _pode_adicionar(parcial, sapato, filtros, prefs, restricoes)
        ]
        if com_sapato:
            completos = [(look, False) for look in com_sapato]
        elif base is not None and base.categoria in SAPATOS:
            completos = []  # a peça-base é o sapato e não combina com esta base
        else:
            completos = [(parcial, True)]

        for look, sem_sapato in completos:
            if not base_casaco and not registrar(look, sem_sapato):
                return resultado
            if incluir_casaco:
                for casaco in casacos:
                    if _pode_adicionar(look, casaco, filtros, prefs, restricoes):
                        if not registrar(look + (casaco,), sem_sapato):
                            return resultado

    if not resultado.candidatos:
        resultado.motivo = _motivo_sem_candidatos(cimas, baixos, vestidos)
    return resultado


def _motivo_sem_candidatos(cimas, baixos, vestidos) -> str:
    if not vestidos and not (cimas and baixos):
        faltando = []
        if not cimas:
            faltando.append("parte de cima")
        if not baixos:
            faltando.append("parte de baixo")
        return (
            f"Nenhuma {' nem '.join(faltando)} nem vestido compatível com os filtros escolhidos."
        )
    return "Nenhuma combinação respeita as regras de cores e as restrições cadastradas."
