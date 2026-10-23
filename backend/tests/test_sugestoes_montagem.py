"""Montagem de candidatos (docs/regras-sugestoes.md, seções 2 a 4 e 6)."""

import pytest

from app.services.sugestoes.montagem import (
    MOTIVO_ACESSORIO,
    MOTIVO_ARMARIO_VAZIO,
    campos_incompletos,
    gerar_candidatos,
)
from app.services.sugestoes.tipos import Filtros, PreferenciasMotor, Restricoes
from tests.fabrica import peca

PREFS = PreferenciasMotor(criatividade=3)


def gerar(pecas, filtros=Filtros(), prefs=PREFS, restricoes=Restricoes(), **kwargs):
    return gerar_candidatos(pecas, filtros, prefs, restricoes, **kwargs)


def categorias(candidato):
    return sorted(p.categoria for p in candidato.pecas)


# --- Estrutura ----------------------------------------------------------------


def test_estruturas_validas_e_sem_acessorios():
    cima, baixo = peca("Camisetas", "Branco"), peca("Calças", "Preto")
    vestido, sapato = peca("Vestidos", "Azul"), peca("Sapatos", "Preto")
    bolsa = peca("Acessórios", "Bege")
    resultado = gerar([cima, baixo, vestido, sapato, bolsa])
    assert sorted(categorias(c) for c in resultado.candidatos) == [
        ["Calças", "Camisetas", "Sapatos"],
        ["Sapatos", "Vestidos"],
    ]
    assert all(not c.sem_sapato for c in resultado.candidatos)


def test_sem_sapato_compativel_gera_look_sem_sapato_marcado():
    cima, baixo = peca("Camisetas", "Vermelho"), peca("Calças", "Preto")
    sapato_verde = peca("Sapatos", "Verde")  # Vermelho + Verde = 4, acima da criatividade 3
    resultado = gerar([cima, baixo, sapato_verde])
    assert len(resultado.candidatos) == 1
    assert resultado.candidatos[0].sem_sapato
    assert categorias(resultado.candidatos[0]) == ["Calças", "Camisetas"]


def test_com_sapato_compativel_nao_ha_variante_sem_sapato():
    resultado = gerar(
        [peca("Camisetas", "Branco"), peca("Calças", "Preto"), peca("Sapatos", "Preto")]
    )
    assert [c.sem_sapato for c in resultado.candidatos] == [False]


def test_casaco_so_entra_com_outono_inverno_ou_sobreposicao_preferida():
    pecas = [
        peca("Camisetas", "Branco"),
        peca("Calças", "Preto"),
        peca("Sapatos", "Preto"),
        peca("Casacos", "Bege"),
    ]
    assert all("Casacos" not in categorias(c) for c in gerar(pecas).candidatos)

    com_inverno = gerar(pecas, filtros=Filtros(estacao="Inverno"))
    assert any("Casacos" in categorias(c) for c in com_inverno.candidatos)

    com_sobreposicao = gerar(
        pecas, prefs=PreferenciasMotor(criatividade=3, sobreposicoes=frozenset({"Jaqueta"}))
    )
    assert any("Casacos" in categorias(c) for c in com_sobreposicao.candidatos)


# --- Restrições e criatividade ------------------------------------------------


def test_peca_evitada_nunca_entra():
    cima, baixo, sapato = peca("Camisetas", "Branco"), peca("Calças", "Preto"), peca("Sapatos", "Preto")
    resultado = gerar([cima, baixo, sapato], restricoes=Restricoes(pecas_evitadas=frozenset({baixo.id})))
    assert resultado.candidatos == []
    assert resultado.motivo


def test_par_evitado_nunca_entra_mesmo_sendo_par_favorito():
    cima, baixo, sapato = peca("Camisetas", "Amarelo"), peca("Calças", "Roxo"), peca("Sapatos", "Branco")
    prefs = PreferenciasMotor(criatividade=1, pares_favoritos=frozenset({frozenset({"Amarelo", "Roxo"})}))
    assert len(gerar([cima, baixo, sapato], prefs=prefs).candidatos) == 1

    restricoes = Restricoes(pares_evitados=frozenset({frozenset({cima.id, baixo.id})}))
    assert gerar([cima, baixo, sapato], prefs=prefs, restricoes=restricoes).candidatos == []


def test_nenhum_candidato_acima_da_ousadia_maxima():
    pecas = [
        peca("Camisetas", cor)
        for cor in ("Vermelho", "Amarelo", "Azul", "Branco")
    ] + [peca("Calças", cor) for cor in ("Verde", "Laranja", "Preto")] + [peca("Sapatos", "Preto")]
    for criatividade in range(1, 6):
        resultado = gerar(pecas, prefs=PreferenciasMotor(criatividade=criatividade))
        assert all(c.ousadia <= criatividade - 1 for c in resultado.candidatos)


# --- Filtros e coringas -------------------------------------------------------


def test_filtro_de_ocasiao_aceita_peca_sem_ocasiao_como_coringa():
    cima = peca("Camisetas", "Branco", ocasioes=("Trabalho",))
    baixo_sem_ocasiao = peca("Calças", "Preto", ocasioes=())
    baixo_festa = peca("Calças", "Preto", ocasioes=("Festa",))
    sapato = peca("Sapatos", "Preto", ocasioes=("Trabalho",))
    resultado = gerar([cima, baixo_sem_ocasiao, baixo_festa, sapato], filtros=Filtros(ocasiao="Trabalho"))
    assert len(resultado.candidatos) == 1
    assert resultado.candidatos[0].coringas == {baixo_sem_ocasiao.id}


def test_no_maximo_um_coringa_por_look():
    cima, baixo = peca("Camisetas", None), peca("Calças", None)
    sapato = peca("Sapatos", "Preto")
    assert gerar([cima, baixo, sapato]).candidatos == []


def test_peca_sem_estilo_sem_filtro_de_estilo_nao_e_coringa():
    cima = peca("Camisetas", "Branco", estilo=None)
    baixo = peca("Calças", None)  # coringa por falta de cor
    sapato = peca("Sapatos", "Preto")
    resultado = gerar([cima, baixo, sapato])
    assert len(resultado.candidatos) == 1
    assert resultado.candidatos[0].coringas == {baixo.id}


def test_estacao_vazia_ou_todas_servem_para_qualquer_estacao():
    pecas = [
        peca("Camisetas", "Branco", estacao=None),
        peca("Calças", "Preto", estacao="Todas as estações"),
        peca("Calças", "Bege", estacao="Verão"),
        peca("Sapatos", "Preto", estacao="Inverno"),
    ]
    resultado = gerar(pecas, filtros=Filtros(estacao="Inverno"))
    assert len(resultado.candidatos) == 1
    assert resultado.candidatos[0].coringas == frozenset()


def test_filtro_de_cor_exige_ao_menos_uma_peca_da_cor():
    pecas = [
        peca("Camisetas", "Branco"),
        peca("Camisetas", "Azul"),
        peca("Calças", "Preto"),
        peca("Sapatos", "Preto"),
    ]
    resultado = gerar(pecas, filtros=Filtros(cor="Azul"))
    assert len(resultado.candidatos) == 1
    assert any(p.cor == "Azul" for p in resultado.candidatos[0].pecas)


def test_campos_incompletos_ignora_estacao():
    assert campos_incompletos(peca("Calças", None, estilo=None, ocasioes=())) == [
        "cor",
        "ocasião",
        "estilo",
    ]
    assert campos_incompletos(peca("Calças", "Preto", estacao=None)) == []


# --- Peça-base ----------------------------------------------------------------


def test_peca_base_aparece_em_todos_os_looks():
    base = peca("Calças", "Preto")
    pecas = [peca("Camisetas", "Branco"), peca("Camisetas", "Cinza"), base, peca("Calças", "Bege"), peca("Sapatos", "Preto")]
    resultado = gerar(pecas, peca_base_id=base.id)
    assert len(resultado.candidatos) == 2
    assert all(base in c.pecas for c in resultado.candidatos)


def test_peca_base_evitada_entra_com_marcacao_mas_outras_evitadas_nao():
    base, outra_evitada = peca("Calças", "Preto"), peca("Camisetas", "Cinza")
    pecas = [peca("Camisetas", "Branco"), outra_evitada, base, peca("Sapatos", "Preto")]
    restricoes = Restricoes(pecas_evitadas=frozenset({base.id, outra_evitada.id}))
    resultado = gerar(pecas, restricoes=restricoes, peca_base_id=base.id)
    assert len(resultado.candidatos) == 1
    assert resultado.candidatos[0].base_evitada
    assert outra_evitada not in resultado.candidatos[0].pecas


@pytest.mark.parametrize(
    "filtros, campo",
    [
        (Filtros(ocasiao="Trabalho"), "ocasiao"),
        (Filtros(estilo="Formal"), "estilo"),
        (Filtros(estacao="Inverno"), "estacao"),
    ],
)
def test_peca_base_incompativel_com_filtro_gera_conflito(filtros, campo):
    base = peca("Calças", "Preto", estilo="Casual", estacao="Verão", ocasioes=("Festa",))
    pecas = [peca("Camisetas", "Branco"), base, peca("Sapatos", "Preto")]
    resultado = gerar(pecas, filtros=filtros, peca_base_id=base.id)
    assert resultado.candidatos == []
    assert [c.filtro for c in resultado.conflitos] == [campo]


def test_peca_base_sem_o_campo_do_filtro_nao_conflita_vira_coringa():
    base = peca("Calças", "Preto", ocasioes=())
    pecas = [peca("Camisetas", "Branco", ocasioes=("Trabalho",)), base, peca("Sapatos", "Preto", ocasioes=("Trabalho",))]
    resultado = gerar(pecas, filtros=Filtros(ocasiao="Trabalho"), peca_base_id=base.id)
    assert resultado.conflitos == []
    assert resultado.candidatos[0].coringas == {base.id}


def test_peca_base_acessorio_informa_motivo():
    bolsa = peca("Acessórios", "Bege")
    resultado = gerar([peca("Camisetas", "Branco"), bolsa], peca_base_id=bolsa.id)
    assert resultado.candidatos == [] and resultado.motivo == MOTIVO_ACESSORIO


# --- Limite e motivos ---------------------------------------------------------


def test_limite_de_candidatos():
    pecas = (
        [peca("Camisetas", "Branco") for _ in range(10)]
        + [peca("Calças", "Preto") for _ in range(10)]
        + [peca("Sapatos", "Preto") for _ in range(5)]
    )
    assert len(gerar(pecas).candidatos) == 500
    resultado = gerar(pecas, limite=100)
    assert len(resultado.candidatos) == 100 and resultado.limite_atingido


def test_armario_vazio_informa_motivo():
    assert gerar([]).motivo == MOTIVO_ARMARIO_VAZIO


def test_sem_parte_de_baixo_nem_vestido_informa_o_que_falta():
    resultado = gerar([peca("Camisetas", "Branco"), peca("Sapatos", "Preto")])
    assert resultado.candidatos == []
    assert "parte de baixo" in resultado.motivo


def test_varias_estacoes_basta_uma_bater_com_a_pedida():
    pecas = [
        peca("Camisetas", "Branco"),
        peca("Calças", "Preto", estacoes=("Outono", "Inverno")),
        peca("Sapatos", "Preto"),
    ]
    assert gerar(pecas, filtros=Filtros(estacao="Inverno")).candidatos
    assert gerar(pecas, filtros=Filtros(estacao="Outono")).candidatos
    assert not gerar(pecas, filtros=Filtros(estacao="Verão")).candidatos


def test_peca_multicolorida_conta_como_cada_uma_das_cores():
    # Rosa com Azul-claro é ousadia 2; a variante Azul fecha em 1 (criatividade 2).
    multicolor = peca("Camisetas", "Rosa", cores_extras=("Azul",))
    pecas = [multicolor, peca("Calças", "Azul-claro"), peca("Sapatos", "Preto")]
    resultado = gerar(pecas, prefs=PreferenciasMotor(criatividade=2))
    assert len(resultado.candidatos) == 1
    assert {p.cor for p in resultado.candidatos[0].pecas if p.id == multicolor.id} == {"Azul"}


def test_peca_multicolorida_atende_filtro_por_cor_secundaria():
    pecas = [
        peca("Camisetas", "Rosa", cores_extras=("Branco",)),
        peca("Calças", "Preto"),
        peca("Sapatos", "Preto"),
    ]
    assert gerar(pecas, filtros=Filtros(cor="Branco")).candidatos
    assert not gerar(pecas, filtros=Filtros(cor="Verde")).candidatos


def test_peca_multicolorida_nao_duplica_o_look():
    pecas = [
        peca("Camisetas", "Rosa", cores_extras=("Branco", "Azul")),
        peca("Calças", "Preto"),
        peca("Sapatos", "Preto"),
    ]
    assert len(gerar(pecas).candidatos) == 1


def test_varios_estilos_basta_um_bater_com_o_filtro():
    pecas = [
        peca("Camisetas", "Branco", estilos=("Elegante", "Casual")),
        peca("Calças", "Preto", estilos=("Casual", "Elegante")),
        peca("Sapatos", "Preto", estilos=("Casual", "Elegante")),
    ]
    assert gerar(pecas, filtros=Filtros(estilo="Casual")).candidatos
    assert gerar(pecas, filtros=Filtros(estilo="Elegante")).candidatos
    assert not gerar(pecas, filtros=Filtros(estilo="Formal")).candidatos
