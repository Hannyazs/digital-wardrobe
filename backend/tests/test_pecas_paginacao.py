"""`GET /pecas` com paginação e filtros (E11.F1.1), contra o Postgres local
(fixtures em `conftest.py`; sem o banco no ar, os testes de rota são pulados).

Os testes de paridade comparam o servidor com uma réplica em Python das regras
de `filtrarPecas` do app (mobile/lib/views/wardrobe/wardrobe_controller.dart).
"""

import pytest
from sqlalchemy.dialects import postgresql

from app.services.peca_consulta import CATEGORIAS_FIXAS, condicoes_de_filtro, consulta_de_pecas

PECAS = "/api/v1/pecas"


def _como(usuario) -> dict:
    return {"X-Usuario": str(usuario)}


def _criar(client, usuario, categoria="Camisetas", **campos):
    resposta = client.post(
        PECAS,
        headers=_como(usuario),
        json={"imagem_url": "/uploads/x.png", "categoria": categoria, **campos},
    )
    assert resposta.status_code == 201, resposta.text
    return resposta.json()


def _listar(client, usuario, **params):
    return client.get(PECAS, headers=_como(usuario), params=params)


def _ids(resposta) -> list[str]:
    return [p["id"] for p in resposta.json()]


# --- Sem banco: o SQL gerado ---------------------------------------------------


def _sql(**filtros) -> str:
    padrao = dict(categorias=[], outras=False, cores=[], estacoes=[], ocasioes=[])
    consulta = consulta_de_pecas("00000000-0000-0000-0000-000000000001", condicoes_de_filtro(**{**padrao, **filtros}))
    return str(consulta.compile(dialect=postgresql.dialect()))


def test_sql_ordena_por_criado_em_desc_e_id():
    assert "ORDER BY pecas.criado_em DESC, pecas.id" in _sql()


def test_sql_sem_filtros_so_filtra_por_usuario():
    sql = _sql()
    assert "pecas.usuario_id =" in sql
    assert "categoria" not in sql.split("WHERE")[1].split("ORDER")[0]


def test_sql_cor_olha_principal_e_secundarias():
    sql = _sql(cores=["Azul"])
    assert "pecas.cor_principal IN" in sql
    assert "pecas.cores_secundarias &&" in sql


def test_sql_estacao_aceita_todas_as_estacoes():
    sql = _sql(estacoes=["Verão"])
    assert "pecas.estacoes &&" in sql
    assert "ANY (pecas.estacoes)" in sql


def test_sql_outras_exclui_as_categorias_fixas():
    assert "pecas.categoria NOT IN" in _sql(outras=True)


# --- Rotas ---------------------------------------------------------------------


def test_sem_parametros_devolve_todas_na_ordem_do_mais_novo(client, usuarios):
    eu = usuarios()
    criadas = [_criar(client, eu, subcategoria=str(i)) for i in range(5)]

    resposta = _listar(client, eu)

    assert resposta.status_code == 200
    assert _ids(resposta) == [p["id"] for p in reversed(criadas)]
    assert resposta.headers["X-Total-Count"] == "5"


def test_paginas_seguem_uma_da_outra_sem_repetir(client, usuarios):
    eu = usuarios()
    for i in range(7):
        _criar(client, eu, subcategoria=str(i))
    todas = _ids(_listar(client, eu))

    p1 = _listar(client, eu, limite=3, deslocamento=0)
    p2 = _listar(client, eu, limite=3, deslocamento=3)
    p3 = _listar(client, eu, limite=3, deslocamento=6)

    assert _ids(p1) + _ids(p2) + _ids(p3) == todas
    assert [len(_ids(p)) for p in (p1, p2, p3)] == [3, 3, 1]
    assert p1.headers["X-Total-Count"] == p3.headers["X-Total-Count"] == "7"


def test_limite_acima_do_maximo_e_rejeitado_com_422(client, usuarios):
    resposta = _listar(client, usuarios(), limite=101)
    assert resposta.status_code == 422


@pytest.mark.parametrize("params", [{"limite": 0}, {"deslocamento": -1}])
def test_limite_e_deslocamento_invalidos_dao_422(client, usuarios, params):
    assert _listar(client, usuarios(), **params).status_code == 422


def test_nao_mostra_pecas_de_outro_usuario_nem_conta_elas(client, usuarios):
    ana, bia = usuarios(), usuarios()
    _criar(client, ana)
    _criar(client, bia)
    _criar(client, bia)

    resposta = _listar(client, ana, limite=10)

    assert len(resposta.json()) == 1
    assert resposta.headers["X-Total-Count"] == "1"


def test_filtro_de_categoria_aceita_varias_e_a_gaveta_outras(client, usuarios):
    eu = usuarios()
    camiseta = _criar(client, eu, "Camisetas")
    calca = _criar(client, eu, "Calças")
    _criar(client, eu, "Sapatos")
    estranha = _criar(client, eu, "Gravatas")

    duas = _listar(client, eu, categoria=["Camisetas", "Calças"])
    outras = _listar(client, eu, outras="true")
    ambas = _listar(client, eu, categoria=["Calças"], outras="true")

    assert set(_ids(duas)) == {camiseta["id"], calca["id"]}
    assert _ids(outras) == [estranha["id"]]
    assert set(_ids(ambas)) == {calca["id"], estranha["id"]}
    assert duas.headers["X-Total-Count"] == "2"


# Réplica das regras do app (`filtrarPecas`) para o teste de paridade.
def _cores_da_peca(p):
    return [c for c in [(p["cor_principal"] or "").strip(), *p["cores_secundarias"]] if c]


def _casa(p, cores, estacoes, ocasioes):
    if cores and not any(c in cores for c in _cores_da_peca(p)):
        return False
    if estacoes and not (any(e in estacoes for e in p["estacoes"]) or "Todas as estações" in p["estacoes"]):
        return False
    if ocasioes and not any(o in ocasioes for o in p["ocasioes"]):
        return False
    return True


@pytest.mark.parametrize(
    "cores,estacoes,ocasioes",
    [
        ([], [], []),
        (["Azul"], [], []),
        (["Azul", "Preto"], [], []),
        ([], ["Verão"], []),
        ([], [], ["Trabalho"]),
        (["Azul"], ["Inverno"], []),
        (["Preto"], ["Verão"], ["Casual", "Festa"]),
        (["Rosa"], [], []),  # só aparece como cor secundária
    ],
)
def test_paridade_com_as_regras_do_app(client, usuarios, cores, estacoes, ocasioes):
    eu = usuarios()
    conjunto = [
        dict(cor_principal="Azul", estacoes=["Inverno"], ocasioes=["Trabalho"]),
        dict(cor_principal="Preto", estacoes=["Todas as estações"], ocasioes=["Casual"]),
        dict(cor_principal="Preto", cores_secundarias=["Rosa"], estacoes=["Verão"], ocasioes=["Festa"]),
        dict(cor_principal="Branco", estacoes=["Verão"], ocasioes=["Trabalho", "Casual"]),
        dict(cor_principal=None, estacoes=[], ocasioes=[]),
        dict(cor_principal="Azul", estacoes=["Verão"], ocasioes=[]),
    ]
    todas = [_criar(client, eu, **dados) for dados in conjunto]

    resposta = _listar(client, eu, cor=cores, estacao=estacoes, ocasiao=ocasioes)

    esperado = {p["id"] for p in todas if _casa(p, cores, estacoes, ocasioes)}
    assert set(_ids(resposta)) == esperado
    assert resposta.headers["X-Total-Count"] == str(len(esperado))


def test_filtro_com_paginacao_conta_so_as_filtradas(client, usuarios):
    eu = usuarios()
    for _ in range(5):
        _criar(client, eu, cor_principal="Azul")
    for _ in range(3):
        _criar(client, eu, cor_principal="Preto")

    resposta = _listar(client, eu, cor="Azul", limite=2)

    assert len(resposta.json()) == 2
    assert resposta.headers["X-Total-Count"] == "5"


# Limitação do offset (documentada na E11.F1.1): registram o comportamento real.
def test_peca_criada_entre_paginas_repete_um_item_e_a_deduplicacao_por_id_resolve(client, usuarios):
    eu = usuarios()
    for i in range(4):
        _criar(client, eu, subcategoria=str(i))
    pagina_1 = _ids(_listar(client, eu, limite=2, deslocamento=0))

    _criar(client, eu, subcategoria="nova")  # chega por cima: empurra tudo uma posição
    pagina_2 = _ids(_listar(client, eu, limite=2, deslocamento=2))

    assert set(pagina_1) & set(pagina_2), "o último item da página 1 reaparece na 2"
    vistos = list(dict.fromkeys(pagina_1 + pagina_2))  # deduplicação por id, como no app
    assert len(vistos) == len(pagina_1) + len(pagina_2) - 1


def test_peca_excluida_entre_paginas_pula_um_item(client, usuarios):
    eu = usuarios()
    for i in range(6):
        _criar(client, eu, subcategoria=str(i))
    todas = _ids(_listar(client, eu))
    pagina_1 = _ids(_listar(client, eu, limite=2, deslocamento=0))

    assert client.delete(f"{PECAS}/{pagina_1[0]}", headers=_como(eu)).status_code == 204
    pagina_2 = _ids(_listar(client, eu, limite=2, deslocamento=2))

    pulada = todas[2]  # estaria no começo da página 2 se nada tivesse sido excluído
    assert pulada not in pagina_2, "o item que ocupava a posição 2 foi pulado"


def test_cors_expoe_a_contagem_para_o_flutter_web(client, usuarios):
    from app.core.config import settings

    origem = settings.cors_origins_list[0]
    resposta = client.get(PECAS, headers={**_como(usuarios()), "Origin": origem})

    expostos = resposta.headers.get("access-control-expose-headers", "")
    assert "x-total-count" in expostos.lower()


def test_categorias_fixas_tem_as_13_do_app():
    assert len(CATEGORIAS_FIXAS) == 13 and "Outras" not in CATEGORIAS_FIXAS
