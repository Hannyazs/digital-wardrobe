"""Look do dia e modo rotatividade do critério 5 (E6.F1.1)."""

from datetime import date, timedelta

from app.services.sugestoes.ordenacao import eh_esquecida, ordenar
from app.services.sugestoes.servico import MOTIVO_SEM_MAIS, sugerir_look_do_dia
from app.services.sugestoes.tipos import (
    Candidato,
    ContextoRotatividade,
    PreferenciasMotor,
    Restricoes,
)
from app.services.sugestoes.montagem import MOTIVO_ARMARIO_VAZIO
from tests.fabrica import peca

HOJE = date(2026, 10, 21)
PREFS = PreferenciasMotor(criatividade=3)


def candidato(*pecas):
    return Candidato(
        pecas=tuple(pecas), ousadia=0, pares_favoritos=frozenset(), coringas=frozenset(), sem_sapato=False
    )


def test_esquecida_nunca_usada_ou_sem_uso_ha_mais_de_30_dias():
    nunca, antiga, recente, limite = (peca("Calças", "Preto") for _ in range(4))
    contexto = ContextoRotatividade(
        data=HOJE,
        ultimos_usos={antiga.id: HOJE - timedelta(days=31), recente.id: HOJE - timedelta(days=1), limite.id: HOJE - timedelta(days=30)},
    )
    assert eh_esquecida(nunca.id, contexto)
    assert eh_esquecida(antiga.id, contexto)
    assert not eh_esquecida(recente.id, contexto)
    assert not eh_esquecida(limite.id, contexto)


def test_look_com_peca_esquecida_vem_primeiro():
    esquecida, usada_ontem = peca("Camisetas", "Branco"), peca("Camisetas", "Cinza")
    calca = peca("Calças", "Preto")
    contexto = ContextoRotatividade(
        data=HOJE, ultimos_usos={usada_ontem.id: HOJE - timedelta(days=1), calca.id: HOJE - timedelta(days=1)}
    )
    com_esquecida, sem_esquecida = candidato(esquecida, calca), candidato(usada_ontem, calca)
    # No Épico 5 (só total de usos) o look com mais usos iria depois de qualquer jeito;
    # aqui o total é igual, e quem decide é a peça esquecida.
    usos = {esquecida.id: 3, usada_ontem.id: 3}
    assert ordenar([sem_esquecida, com_esquecida], PREFS, usos, contexto)[0] is com_esquecida


def test_sem_esquecidas_o_uso_mais_antigo_vem_primeiro():
    a, b, calca = peca("Camisetas", "Branco"), peca("Camisetas", "Cinza"), peca("Calças", "Preto")
    contexto = ContextoRotatividade(
        data=HOJE,
        ultimos_usos={a.id: HOJE - timedelta(days=20), b.id: HOJE - timedelta(days=2), calca.id: HOJE - timedelta(days=25)},
    )
    mais_antigo, mais_recente = candidato(a, calca), candidato(b, calca)
    assert ordenar([mais_recente, mais_antigo], PREFS, {}, contexto)[0] is mais_antigo


def test_criterios_1_a_4_continuam_na_frente_da_rotatividade():
    completa, incompleta_esquecida = peca("Camisetas", "Branco"), peca("Camisetas", "Cinza", estilo=None)
    calca = peca("Calças", "Preto")
    contexto = ContextoRotatividade(data=HOJE, ultimos_usos={completa.id: HOJE - timedelta(days=1), calca.id: HOJE})
    ordem = ordenar([candidato(incompleta_esquecida, calca), candidato(completa, calca)], PREFS, {}, contexto)
    assert completa in ordem[0].pecas


def _armario():
    return [
        peca("Camisetas", "Branco", ocasioes=("Casual", "Trabalho")),
        peca("Camisetas", "Cinza", ocasioes=("Casual",)),
        peca("Calças", "Preto", ocasioes=("Casual", "Trabalho")),
        peca("Sapatos", "Preto", ocasioes=("Casual", "Trabalho")),
    ]


def test_look_do_dia_devolve_um_look_da_ocasiao_e_e_estavel():
    pecas = _armario()
    contexto = ContextoRotatividade(data=HOJE)
    um = sugerir_look_do_dia(pecas, "Trabalho", PREFS, Restricoes(), {}, contexto)
    dois = sugerir_look_do_dia(list(reversed(pecas)), "Trabalho", PREFS, Restricoes(), {}, contexto)
    assert len(um.looks) == 1
    assert all("Trabalho" in p.ocasioes for p in um.looks[0].candidato.pecas)
    assert um.looks[0].candidato == dois.looks[0].candidato
    assert not um.tem_mais  # só uma camiseta serve para Trabalho


def test_outra_sugestao_pula_o_look_descartado():
    pecas = _armario()
    contexto = ContextoRotatividade(data=HOJE)
    primeiro = sugerir_look_do_dia(pecas, "Casual", PREFS, Restricoes(), {}, contexto)
    ids = frozenset(p.id for p in primeiro.looks[0].candidato.pecas)
    segundo = sugerir_look_do_dia(pecas, "Casual", PREFS, Restricoes(), {}, contexto, descartados=[ids])
    assert frozenset(p.id for p in segundo.looks[0].candidato.pecas) != ids
    assert primeiro.tem_mais and not segundo.tem_mais

    acabou = sugerir_look_do_dia(
        pecas, "Casual", PREFS, Restricoes(), {}, contexto,
        descartados=[ids, frozenset(p.id for p in segundo.looks[0].candidato.pecas)],
    )
    assert acabou.looks == [] and acabou.motivo == MOTIVO_SEM_MAIS


def test_armario_insuficiente_informa_motivo():
    vazio = sugerir_look_do_dia([], "Casual", PREFS, Restricoes(), {}, ContextoRotatividade(data=HOJE))
    assert vazio.looks == [] and vazio.motivo == MOTIVO_ARMARIO_VAZIO

    so_camiseta = sugerir_look_do_dia(
        [peca("Camisetas", "Branco")], "Casual", PREFS, Restricoes(), {}, ContextoRotatividade(data=HOJE)
    )
    assert so_camiseta.looks == [] and "parte de baixo" in so_camiseta.motivo
