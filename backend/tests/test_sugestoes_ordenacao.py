"""Ordenação, páginas e textos (docs/regras-sugestoes.md, seções 5 e 6)."""

from collections import Counter

from app.services.sugestoes.ordenacao import avisos, explicar, ordenar, paginar
from app.services.sugestoes.servico import MOTIVO_SEM_MAIS, sugerir
from app.services.sugestoes.tipos import Candidato, Filtros, PreferenciasMotor, Restricoes
from tests.fabrica import peca

PREFS = PreferenciasMotor(criatividade=3)


def candidato(*pecas, ousadia=0, favoritos=(), sem_sapato=False, base_evitada=False):
    return Candidato(
        pecas=tuple(pecas),
        ousadia=ousadia,
        pares_favoritos=frozenset(frozenset(f) for f in favoritos),
        coringas=frozenset(),
        sem_sapato=sem_sapato,
        base_evitada=base_evitada,
    )


def primeiro(a, b, prefs=PREFS, usos=None):
    return ordenar([b, a], prefs, usos or {})[0]


# --- Critérios, um de cada vez -------------------------------------------------


def test_criterio_1_par_favorito_vem_antes_de_tudo():
    com_favorito = candidato(peca("Camisetas", "Amarelo", estilo=None), peca("Calças", "Roxo"), favoritos=[("Amarelo", "Roxo")])
    completo = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto"))
    assert primeiro(com_favorito, completo) is com_favorito


def test_criterio_2_menos_pecas_incompletas():
    completo = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto"))
    incompleto = candidato(peca("Camisetas", "Branco", estilo=None), peca("Calças", "Preto"))
    assert primeiro(completo, incompleto) is completo


def test_criterio_3_mais_pecas_com_estilo_preferido():
    prefs = PreferenciasMotor(criatividade=3, estilos=frozenset({"Elegante"}))
    elegante = candidato(peca("Camisetas", "Branco", estilo="Elegante"), peca("Calças", "Preto", estilo="Elegante"))
    casual = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto"))
    assert primeiro(elegante, casual, prefs) is elegante


def test_criterio_4_menos_estilos_distintos():
    coerente = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto"))
    misturado = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto", estilo="Formal"))
    assert primeiro(coerente, misturado) is coerente


def test_criterio_5_menos_usos():
    a, b = peca("Camisetas", "Branco"), peca("Calças", "Preto")
    c, d = peca("Camisetas", "Cinza"), peca("Calças", "Bege")
    pouco_usado, muito_usado = candidato(a, b), candidato(c, d)
    assert primeiro(pouco_usado, muito_usado, usos={c.id: 5}) is pouco_usado


def test_criterio_6_ousadia_mais_proxima_do_maximo():
    perto = candidato(peca("Camisetas", "Azul"), peca("Calças", "Verde"), ousadia=2)
    longe = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto"), ousadia=0)
    assert primeiro(perto, longe) is perto


def test_prioridade_criterio_5_nao_passa_na_frente_do_2():
    completo_usado = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto"))
    incompleto_novo = candidato(peca("Camisetas", "Cinza", estilo=None), peca("Calças", "Bege"))
    usos = {p.id: 10 for p in completo_usado.pecas}
    assert primeiro(completo_usado, incompleto_novo, usos=usos) is completo_usado


def test_empate_total_decidido_pelos_ids_e_independe_da_ordem_de_entrada():
    a = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto"))
    b = candidato(peca("Camisetas", "Branco"), peca("Calças", "Preto"))
    assert ordenar([a, b], PREFS, {}) == ordenar([b, a], PREFS, {})


# --- Páginas e descartes --------------------------------------------------------


def _armario():
    return (
        [peca("Camisetas", c) for c in ("Branco", "Cinza", "Bege")]
        + [peca("Calças", c) for c in ("Preto", "Marrom")]
        + [peca("Sapatos", "Preto")]
    )


def test_pagina_tem_ate_3_looks_e_cada_peca_em_no_maximo_2():
    pecas = _armario() + [peca("Sapatos", "Branco")]
    resultado = sugerir(pecas, Filtros(), PREFS, Restricoes(), {})
    assert len(resultado.looks) == 3
    contagem = Counter(p.id for look in resultado.looks for p in look.candidato.pecas)
    assert max(contagem.values()) <= 2


def test_paginas_nao_repetem_looks_e_terminam():
    # 3 camisetas x 2 calças x 1 sapato = 6 looks; o sapato só cabe em 2 por página.
    vistos, pagina = [], 1
    while True:
        resultado = sugerir(_armario(), Filtros(), PREFS, Restricoes(), {}, pagina=pagina)
        vistos += [frozenset(p.id for p in l.candidato.pecas) for l in resultado.looks]
        if not resultado.tem_mais:
            break
        pagina += 1
    assert len(vistos) == len(set(vistos)) == 6
    assert pagina == 3


def test_mesma_entrada_mesma_resposta():
    pecas = _armario()
    um = sugerir(pecas, Filtros(), PREFS, Restricoes(), {}, pagina=2)
    dois = sugerir(list(reversed(pecas)), Filtros(), PREFS, Restricoes(), {}, pagina=2)
    assert [l.candidato for l in um.looks] == [l.candidato for l in dois.looks]


def test_descartados_ficam_de_fora():
    pecas = _armario()
    primeira = sugerir(pecas, Filtros(), PREFS, Restricoes(), {})
    descartado = frozenset(p.id for p in primeira.looks[0].candidato.pecas)
    nova = sugerir(pecas, Filtros(), PREFS, Restricoes(), {}, descartados=[descartado])
    assert descartado not in [frozenset(p.id for p in l.candidato.pecas) for l in nova.looks]


def test_todos_descartados_informa_motivo():
    pecas = [peca("Camisetas", "Branco"), peca("Calças", "Preto"), peca("Sapatos", "Preto")]
    resultado = sugerir(pecas, Filtros(), PREFS, Restricoes(), {}, descartados=[frozenset(p.id for p in pecas)])
    assert resultado.looks == [] and resultado.motivo == MOTIVO_SEM_MAIS


def test_pagina_alem_da_ultima_vem_vazia():
    resultado = sugerir(_armario(), Filtros(), PREFS, Restricoes(), {}, pagina=10)
    assert resultado.looks == [] and not resultado.tem_mais


def test_paginar_pula_look_que_repetiria_peca_pela_terceira_vez():
    sapato = peca("Sapatos", "Preto")
    looks = [candidato(peca("Camisetas", "Branco"), sapato) for _ in range(3)]
    pagina, tem_mais = paginar(looks, 1)
    assert len(pagina) == 2 and tem_mais


# --- Explicações e avisos ------------------------------------------------------


def test_explicacoes():
    favorito = candidato(peca("Camisetas", "Amarelo"), peca("Calças", "Roxo"), favoritos=[("Amarelo", "Roxo")])
    assert "Usa seu par de cores favorito: Amarelo + Roxo." in explicar(favorito, PREFS, Filtros())

    tom_sobre_tom = candidato(peca("Camisas", "Azul"), peca("Calças", "Azul-claro"), peca("Sapatos", "Branco"))
    assert "Azul e Azul-claro: tom sobre tom." in explicar(tom_sobre_tom, PREFS, Filtros())

    trabalho = candidato(peca("Camisetas", "Branco", ocasioes=("Trabalho",)), peca("Calças", "Preto", ocasioes=("Trabalho",)))
    assert "Todas as peças servem para Trabalho." in explicar(trabalho, PREFS, Filtros(ocasiao="Trabalho"))


def test_coringa_nao_e_descrito_como_compativel():
    com_coringa = candidato(peca("Camisetas", "Branco", ocasioes=("Trabalho",)), peca("Calças", "Preto", ocasioes=()))
    frases = explicar(com_coringa, PREFS, Filtros(ocasiao="Trabalho"))
    assert not any("Trabalho" in f for f in frases)


def test_avisos():
    look = candidato(peca("Calças", None, estilo=None), peca("Camisetas", "Branco"), sem_sapato=True, base_evitada=True)
    assert avisos(look) == [
        "Você marcou esta peça como evitada.",
        "Calças: cadastro incompleto (sem cor, estilo).",
        "Falta calçado compatível com este look.",
    ]
