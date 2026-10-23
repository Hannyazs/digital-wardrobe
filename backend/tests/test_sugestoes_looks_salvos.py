"""Looks já salvos: não voltam na aba Sugestões (E5.F1.3) e o look do dia sabe
qual look já existe (E6.F1.3). docs/regras-sugestoes.md, seção 6."""

import uuid

from app.services.sugestoes.servico import (
    MOTIVO_SEM_MAIS,
    MOTIVO_TODOS_SALVOS,
    looks_por_conjunto,
    sugerir,
)
from app.services.sugestoes.tipos import Filtros, PreferenciasMotor, Restricoes
from tests.fabrica import peca

# Com sobreposição preferida, o motor também monta a versão com casaco.
PREFS = PreferenciasMotor(criatividade=3, sobreposicoes=frozenset({"Jaqueta"}))


def _ids(resultado):
    return [frozenset(p.id for p in look.candidato.pecas) for look in resultado.looks]


def test_looks_por_conjunto_agrupa_as_pecas_de_cada_look():
    l1, l2 = uuid.uuid4(), uuid.uuid4()
    a, b, c = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    assert looks_por_conjunto([(l1, a), (l2, c), (l1, b)]) == {
        frozenset({a, b}): l1,
        frozenset({c}): l2,
    }
    assert looks_por_conjunto([]) == {}


def test_looks_com_as_mesmas_pecas_fica_o_primeiro():
    l_novo, l_antigo, a = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    assert looks_por_conjunto([(l_novo, a), (l_antigo, a)]) == {frozenset({a}): l_novo}


def test_look_salvo_nao_volta_mas_a_versao_com_casaco_sim():
    camiseta, calca, sapato = peca("Camisetas", "Branco"), peca("Calças", "Preto"), peca("Sapatos", "Preto")
    casaco = peca("Casacos", "Bege")
    pecas = [camiseta, calca, sapato, casaco]
    salvo = frozenset({camiseta.id, calca.id, sapato.id})

    antes = _ids(sugerir(pecas, Filtros(), PREFS, Restricoes(), {}))
    assert salvo in antes

    depois = _ids(sugerir(pecas, Filtros(), PREFS, Restricoes(), {}, salvos=[salvo]))
    assert salvo not in depois
    assert salvo | {casaco.id} in depois


def test_so_looks_salvos_disponiveis_explica_o_motivo():
    pecas = [peca("Camisetas", "Branco"), peca("Calças", "Preto"), peca("Sapatos", "Preto")]
    salvos = list(looks_por_conjunto([(uuid.UUID(int=999), p.id) for p in pecas]))
    resultado = sugerir(pecas, Filtros(), PreferenciasMotor(), Restricoes(), {}, salvos=salvos)
    assert resultado.looks == [] and resultado.motivo == MOTIVO_TODOS_SALVOS


def test_descartados_na_sessao_continuam_com_o_motivo_antigo():
    pecas = [peca("Camisetas", "Branco"), peca("Calças", "Preto"), peca("Sapatos", "Preto")]
    unico = frozenset(p.id for p in pecas)
    resultado = sugerir(pecas, Filtros(), PreferenciasMotor(), Restricoes(), {}, descartados=[unico])
    assert resultado.motivo == MOTIVO_SEM_MAIS
    # Página além da última: "não há mais".
    pagina2 = sugerir(pecas, Filtros(), PreferenciasMotor(), Restricoes(), {}, pagina=2, salvos=[])
    assert pagina2.motivo == MOTIVO_SEM_MAIS
