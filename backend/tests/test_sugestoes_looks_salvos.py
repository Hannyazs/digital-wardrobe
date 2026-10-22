"""E5.F1.3: looks já salvos não voltam na aba Sugestões (docs/regras-sugestoes.md, seção 6)."""

import uuid

from app.services.sugestoes.servico import MOTIVO_SEM_MAIS, conjuntos_por_look, sugerir
from app.services.sugestoes.tipos import Filtros, PreferenciasMotor, Restricoes
from tests.fabrica import peca

# Com sobreposição preferida, o motor também monta a versão com casaco.
PREFS = PreferenciasMotor(criatividade=3, sobreposicoes=frozenset({"Jaqueta"}))


def _ids(resultado):
    return [frozenset(p.id for p in look.candidato.pecas) for look in resultado.looks]


def test_conjuntos_por_look_agrupa_as_pecas_de_cada_look():
    l1, l2 = uuid.uuid4(), uuid.uuid4()
    a, b, c = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    conjuntos = conjuntos_por_look([(l1, a), (l2, c), (l1, b)])
    assert sorted(conjuntos, key=len) == [frozenset({c}), frozenset({a, b})]
    assert conjuntos_por_look([]) == []


def test_look_salvo_nao_volta_mas_a_versao_com_casaco_sim():
    camiseta, calca, sapato = peca("Camisetas", "Branco"), peca("Calças", "Preto"), peca("Sapatos", "Preto")
    casaco = peca("Casacos", "Bege")
    pecas = [camiseta, calca, sapato, casaco]
    salvo = frozenset({camiseta.id, calca.id, sapato.id})

    antes = _ids(sugerir(pecas, Filtros(), PREFS, Restricoes(), {}))
    assert salvo in antes

    depois = _ids(sugerir(pecas, Filtros(), PREFS, Restricoes(), {}, descartados=[salvo]))
    assert salvo not in depois
    assert salvo | {casaco.id} in depois


def test_so_looks_salvos_disponiveis_informa_motivo():
    pecas = [peca("Camisetas", "Branco"), peca("Calças", "Preto"), peca("Sapatos", "Preto")]
    salvos = conjuntos_por_look([(uuid.UUID(int=999), p.id) for p in pecas])
    resultado = sugerir(pecas, Filtros(), PreferenciasMotor(), Restricoes(), {}, descartados=salvos)
    assert resultado.looks == [] and resultado.motivo == MOTIVO_SEM_MAIS
