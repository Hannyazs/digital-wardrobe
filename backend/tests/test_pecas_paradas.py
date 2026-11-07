"""Peças paradas e "lembrar depois" (E13.F1.1).

As regras de data são testadas sem banco; as rotas, contra o Postgres local
(fixtures em `conftest.py`; sem o banco no ar, os testes de rota são pulados).
`hoje` vai sempre explícito, na data UTC (a mesma de `criado_em::date` no banco).
"""

from datetime import date, datetime, timedelta, timezone

import psycopg2
import pytest

from app.services.pecas_paradas import (
    DIAS_ADIAMENTO,
    DIAS_PARADA,
    data_de_corte,
    dias_parada,
    esta_parada,
    fim_do_adiamento,
)
from tests.conftest import _psycopg2_dsn

PECAS = "/api/v1/pecas"
LOOKS = "/api/v1/looks"
HOJE = datetime.now(timezone.utc).date()


def _como(usuario) -> dict:
    return {"X-Usuario": str(usuario)}


# --- Regras puras ----------------------------------------------------------------


def test_prazos_sao_90_e_30_dias():
    assert (DIAS_PARADA, DIAS_ADIAMENTO) == (90, 30)
    assert data_de_corte(date(2026, 4, 1)) == date(2026, 1, 1)
    assert fim_do_adiamento(date(2026, 1, 1)) == date(2026, 1, 31)


@pytest.mark.parametrize("dias, parada", [(89, False), (90, True), (200, True)])
def test_limite_de_dias_pelo_ultimo_uso(dias, parada):
    hoje = date(2026, 11, 6)
    criado = datetime(2025, 1, 1, tzinfo=timezone.utc)
    assert esta_parada(hoje - timedelta(days=dias), criado, None, hoje) is parada


@pytest.mark.parametrize("dias, parada", [(89, False), (90, True)])
def test_nunca_usada_conta_do_cadastro(dias, parada):
    hoje = date(2026, 11, 6)
    criado = datetime.combine(hoje - timedelta(days=dias), datetime.min.time(), timezone.utc)
    assert esta_parada(None, criado, None, hoje) is parada
    assert dias_parada(None, criado, hoje) == dias


def test_uso_recente_vale_mesmo_com_cadastro_antigo():
    hoje = date(2026, 11, 6)
    assert not esta_parada(hoje - timedelta(days=10), date(2024, 1, 1), None, hoje)


@pytest.mark.parametrize("adiado_ate, parada", [(None, True), (date(2026, 11, 7), False), (date(2026, 11, 6), True)])
def test_adiamento_vale_ate_a_data_exclusive(adiado_ate, parada):
    hoje = date(2026, 11, 6)
    assert esta_parada(None, date(2025, 1, 1), adiado_ate, hoje) is parada


# --- Rotas -----------------------------------------------------------------------


@pytest.fixture
def envelhecer():
    """Recua o `criado_em` de uma peça em N dias (o cadastro é sempre "agora")."""
    conexao = psycopg2.connect(_psycopg2_dsn())

    def recuar(peca_id: str, dias: int) -> None:
        with conexao, conexao.cursor() as cursor:
            cursor.execute(
                "UPDATE pecas SET criado_em = now() - make_interval(days => %s) WHERE id = %s",
                (dias, peca_id),
            )

    yield recuar
    conexao.close()


def _criar(client, usuario, **campos) -> str:
    resposta = client.post(
        PECAS,
        headers=_como(usuario),
        json={"imagem_url": "/uploads/x.png", "categoria": "Camisetas", **campos},
    )
    assert resposta.status_code == 201, resposta.text
    return resposta.json()["id"]


def _criar_antiga(client, usuario, envelhecer, dias=200, **campos) -> str:
    peca_id = _criar(client, usuario, **campos)
    envelhecer(peca_id, dias)
    return peca_id


def _usar(client, usuario, peca_ids, usado_em: date) -> str:
    look = client.post(LOOKS, headers=_como(usuario), json={"nome": "Look", "peca_ids": peca_ids})
    assert look.status_code == 201, look.text
    look_id = look.json()["id"]
    uso = client.post(f"{LOOKS}/{look_id}/usos", headers=_como(usuario), json={"usado_em": usado_em.isoformat()})
    assert uso.status_code == 201, uso.text
    return look_id


def _paradas(client, usuario, hoje: date = HOJE, **params):
    resposta = client.get(f"{PECAS}/paradas", headers=_como(usuario), params={"hoje": hoje.isoformat(), **params})
    assert resposta.status_code == 200, resposta.text
    return resposta.json()


def _ids(itens) -> list[str]:
    return [item["peca"]["id"] for item in itens]


def _adiar(client, usuario, peca_id, hoje: date = HOJE):
    return client.post(f"{PECAS}/{peca_id}/adiar-lembrete", headers=_como(usuario), params={"hoje": hoje.isoformat()})


@pytest.mark.parametrize("dias, aparece", [(89, False), (90, True)])
def test_ultimo_uso_ha_89_ou_90_dias(client, usuarios, envelhecer, dias, aparece):
    eu = usuarios()
    peca = _criar_antiga(client, eu, envelhecer)
    _usar(client, eu, [peca], HOJE - timedelta(days=dias))

    itens = _paradas(client, eu)

    assert (peca in _ids(itens)) is aparece
    if aparece:
        assert itens[0]["ultimo_uso"] == (HOJE - timedelta(days=dias)).isoformat()
        assert itens[0]["dias_parada"] == dias


@pytest.mark.parametrize("dias, aparece", [(89, False), (90, True)])
def test_nunca_usada_conta_do_cadastro_na_rota(client, usuarios, envelhecer, dias, aparece):
    eu = usuarios()
    peca = _criar_antiga(client, eu, envelhecer, dias=dias)

    itens = _paradas(client, eu)

    assert (peca in _ids(itens)) is aparece
    if aparece:
        assert itens[0]["ultimo_uso"] is None
        assert itens[0]["dias_parada"] == dias


def test_uso_em_look_arquivado_conta(client, usuarios, envelhecer):
    eu = usuarios()
    usada = _criar_antiga(client, eu, envelhecer)
    parada = _criar_antiga(client, eu, envelhecer)
    look_id = _usar(client, eu, [usada], HOJE - timedelta(days=10))
    assert client.delete(f"{LOOKS}/{look_id}", headers=_como(eu)).status_code == 204

    assert _ids(_paradas(client, eu)) == [parada]


def test_o_uso_mais_recente_e_o_que_vale(client, usuarios, envelhecer):
    eu = usuarios()
    peca = _criar_antiga(client, eu, envelhecer)
    _usar(client, eu, [peca], HOJE - timedelta(days=150))
    _usar(client, eu, [peca], HOJE - timedelta(days=5))

    assert _paradas(client, eu) == []


def test_ordena_da_mais_parada_e_respeita_o_limite(client, usuarios, envelhecer):
    eu = usuarios()
    media = _criar_antiga(client, eu, envelhecer, dias=150)
    mais = _criar_antiga(client, eu, envelhecer, dias=300)
    menos = _criar_antiga(client, eu, envelhecer, dias=95)
    usada_ha_120 = _criar_antiga(client, eu, envelhecer, dias=400)
    _usar(client, eu, [usada_ha_120], HOJE - timedelta(days=120))

    assert _ids(_paradas(client, eu)) == [mais, media, usada_ha_120, menos]
    assert _ids(_paradas(client, eu, limite=1)) == [mais]


@pytest.mark.parametrize("limite", [0, 21])
def test_limite_fora_da_faixa_da_422(client, usuarios, limite):
    resposta = client.get(f"{PECAS}/paradas", headers=_como(usuarios()), params={"limite": limite})
    assert resposta.status_code == 422


def test_padrao_e_5_pecas(client, usuarios, envelhecer):
    eu = usuarios()
    for _ in range(6):
        _criar_antiga(client, eu, envelhecer)
    assert len(_paradas(client, eu)) == 5


def test_adiar_esconde_por_30_dias_e_volta_no_31o(client, usuarios, envelhecer):
    eu = usuarios()
    peca = _criar_antiga(client, eu, envelhecer)

    assert _adiar(client, eu, peca).status_code == 204

    assert _paradas(client, eu) == []
    assert _paradas(client, eu, hoje=HOJE + timedelta(days=29)) == []
    assert _ids(_paradas(client, eu, hoje=HOJE + timedelta(days=30))) == [peca]


def test_peca_de_outro_usuario_nunca_aparece_e_adiar_da_404(client, usuarios, envelhecer):
    eu, outra = usuarios(), usuarios()
    dela = _criar_antiga(client, outra, envelhecer)

    assert _paradas(client, eu) == []
    assert _adiar(client, eu, dela).status_code == 404
    assert _ids(_paradas(client, outra)) == [dela], "o 404 não adiou a peça dela"


def test_adiar_peca_inexistente_da_404(client, usuarios):
    assert _adiar(client, usuarios(), "00000000-0000-0000-0000-000000000000").status_code == 404
