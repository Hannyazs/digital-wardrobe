"""Regras de cores (docs/regras-sugestoes.md, seção 1)."""

import pytest

from app.services.sugestoes.cores import avaliar_cores, ousadia_par
from app.services.sugestoes.tipos import PreferenciasMotor
from tests.fabrica import peca


def prefs(criatividade=3, favoritos=()):
    return PreferenciasMotor(
        criatividade=criatividade,
        pares_favoritos=frozenset(frozenset(par) for par in favoritos),
    )


def par(cor_a, cor_b, ton_a=None, ton_b=None):
    return ousadia_par(peca("Camisetas", cor_a, ton_a), peca("Calças", cor_b, ton_b))


@pytest.mark.parametrize(
    "cor_a, cor_b, esperado",
    [
        # Vibrante + Vibrante não altera nada: valores da tabela.
        ("Vermelho", "Laranja", 2),
        ("Vermelho", "Amarelo", 3),
        ("Vermelho", "Verde", 4),
        ("Vermelho", "Azul", 3),
        ("Vermelho", "Roxo", 2),
        ("Laranja", "Azul", 4),
        ("Amarelo", "Roxo", 4),
        ("Verde", "Azul", 2),
        ("Azul", "Roxo", 2),
    ],
)
def test_tabela_de_ousadia_entre_cores_vibrantes(cor_a, cor_b, esperado):
    assert par(cor_a, cor_b) == esperado
    assert par(cor_b, cor_a) == esperado


def test_mesma_familia_vale_1():
    assert par("Vermelho", "Vinho", "Vibrante", "Vibrante") == 1
    assert par("Azul", "Azul-claro", "Vibrante", "Vibrante") == 1


def test_neutro_com_qualquer_cor_vale_0():
    assert par("Preto", "Vermelho") == 0
    assert par("Azul-marinho", "Laranja") == 0
    assert par("Bege", "Branco") == 0


def test_mesma_cor_vale_0():
    assert par("Vermelho", "Vermelho") == 0


def test_pastel_com_pastel_e_escura_com_escura_reduzem_1():
    assert par("Rosa", "Azul-claro", "Pastel", "Pastel") == 2  # 3 - 1
    assert par("Vinho", "Verde", "Escura", "Escura") == 3  # 4 - 1


def test_reducao_nunca_fica_abaixo_de_1_entre_cores_diferentes():
    assert par("Vinho", "Vermelho", "Escura", "Escura") == 1


def test_tonalidades_mistas_nao_alteram():
    assert par("Rosa", "Azul", "Pastel", "Escura") == 3


def test_cor_com_tonalidade_neutra_conta_como_neutra():
    assert par("Verde", "Laranja", "Neutra", "Vibrante") == 0


def test_tonalidade_vazia_usa_a_sugerida_da_cor():
    # Rosa e Azul-claro têm Pastel como tonalidade sugerida.
    assert par("Rosa", "Azul-claro") == 2


def test_cor_fora_da_lista_e_sem_cor():
    assert par("Azul petróleo", "Vermelho") is None
    assert par(None, "Vermelho") is None


# --- Exemplos revisados com a usuária ---------------------------------------


def test_exemplo_monocromatico_azul_na_criatividade_2():
    look = [peca("Camisas", "Azul"), peca("Calças", "Azul-claro"), peca("Sapatos", "Branco")]
    valido, ousadia, _ = avaliar_cores(look, prefs(2))
    assert valido and ousadia == 1


def test_exemplo_vermelho_laranja_amarelo_so_a_partir_da_criatividade_4():
    look = [peca("Camisetas", "Vermelho"), peca("Saias", "Laranja"), peca("Sapatos", "Amarelo")]
    assert avaliar_cores(look, prefs(3))[0] is False
    valido, ousadia, _ = avaliar_cores(look, prefs(4))
    assert valido and ousadia == 3


def test_exemplo_vermelho_e_verde_vibrantes_so_na_criatividade_5():
    look = [peca("Camisetas", "Vermelho"), peca("Calças", "Verde")]
    assert avaliar_cores(look, prefs(4))[0] is False
    assert avaliar_cores(look, prefs(5)) == (True, 4, frozenset())


def test_exemplo_vinho_e_verde_garrafa_escuros_a_partir_da_criatividade_4():
    look = [peca("Camisetas", "Vinho", "Escura"), peca("Calças", "Verde", "Escura")]
    assert avaliar_cores(look, prefs(3))[0] is False
    assert avaliar_cores(look, prefs(4))[0] is True


def test_exemplo_rosa_e_azul_claro_pasteis_na_criatividade_3():
    look = [peca("Camisas", "Rosa", "Pastel"), peca("Calças", "Azul-claro", "Pastel")]
    assert avaliar_cores(look, prefs(3))[0] is True
    assert avaliar_cores(look, prefs(2))[0] is False


def test_exemplo_par_favorito_passa_da_criatividade():
    look = [peca("Camisetas", "Amarelo"), peca("Calças", "Roxo"), peca("Sapatos", "Branco")]
    assert avaliar_cores(look, prefs(1))[0] is False
    valido, ousadia, favoritos = avaliar_cores(look, prefs(1, [("Amarelo", "Roxo")]))
    assert valido and ousadia == 0
    assert favoritos == {frozenset({"Amarelo", "Roxo"})}


def test_exemplo_verde_oliva_neutro_com_laranja_na_criatividade_1():
    look = [peca("Calças", "Verde", "Neutra"), peca("Camisetas", "Laranja"), peca("Sapatos", "Bege")]
    assert avaliar_cores(look, prefs(1))[0] is True


def test_exemplo_neutros_escuros_juntos_sem_penalidade():
    look = [peca("Casacos", "Preto"), peca("Calças", "Marrom"), peca("Sapatos", "Azul-marinho")]
    assert avaliar_cores(look, prefs(1)) == (True, 0, frozenset())


def test_peca_sem_cor_nao_entra_na_ousadia():
    look = [peca("Calças", None), peca("Camisas", "Azul"), peca("Sapatos", "Branco")]
    assert avaliar_cores(look, prefs(1)) == (True, 0, frozenset())


def test_mais_de_3_cores_e_invalido_mesmo_com_favorito():
    look = [
        peca("Camisetas", "Vermelho"),
        peca("Calças", "Laranja"),
        peca("Sapatos", "Amarelo"),
        peca("Casacos", "Verde"),
    ]
    favoritos = [("Vermelho", "Verde"), ("Laranja", "Verde"), ("Amarelo", "Verde")]
    assert avaliar_cores(look, prefs(5, favoritos))[0] is False


def test_cor_repetida_conta_uma_vez_no_limite():
    look = [
        peca("Camisetas", "Vermelho"),
        peca("Calças", "Vermelho"),
        peca("Sapatos", "Laranja"),
        peca("Casacos", "Rosa"),
    ]
    assert avaliar_cores(look, prefs(3))[0] is True
