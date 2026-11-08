"""Isolamento entre usuários (E9.F3.1), contra o Postgres local.

A usuária A tem um pouco de tudo (peças, look, uso, pasta, coleção, referência,
preferências, peça e combinação evitadas). O usuário B tenta ver, alterar,
apagar e referenciar os dados de A por todas as rotas que recebem dados do
usuário. Esperado:

- recurso de A pedido por B → 404 (nunca 200 nem 403, que revelaria que existe);
- relação cruzada (B usando um id de A no corpo) → 404 ou 422 "não encontrado";
- listagens de B sem nenhum id de A;
- no fim, os dados de A exatamente como antes.

Cada listagem também é conferida do lado de A: se ela não mostrasse os dados
de A, "B não vê nada" não provaria coisa alguma.

O usuário vem do cabeçalho `X-Usuario` (fixture `client`): o que se testa aqui
é o filtro por usuário nos routers. A validação do token em si está em
`test_security.py`.

Rotas cobertas (35 de 37): todas as de `pecas`, `looks`, `pastas`,
`preferencias`, `colecoes`, `referencias` e `sugestoes`, menos
`POST /pecas/processar-imagem` e `POST /pecas/upload-original`, que não
leem nem gravam dados de usuário (e ainda não exigem login: E10.F2.2).
"""

import io
import uuid

import pytest
from PIL import Image

API = "/api/v1"
HOJE = "2026-11-08"
# Data bem no futuro: todas as peças contam como "paradas" (90+ dias sem uso).
FUTURO = "2030-01-01"


def _como(usuario) -> dict:
    return {"X-Usuario": str(usuario)}


def _ok(resposta, status=200):
    assert resposta.status_code == status, resposta.text
    return resposta.json() if resposta.content else None


def _imagem() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), "purple").save(buffer, format="PNG")
    return buffer.getvalue()


def _criar_dados(client, usuario) -> dict:
    """Um de cada recurso para o usuário; devolve os ids."""
    h = _como(usuario)
    blusa = _ok(client.post(f"{API}/pecas", headers=h, json={
        "imagem_url": "/uploads/blusa.png", "categoria": "Camisetas", "cor_principal": "Azul",
        "ocasioes": ["Casual"], "estacoes": ["Verão"],
    }), 201)
    calca = _ok(client.post(f"{API}/pecas", headers=h, json={
        "imagem_url": "/uploads/calca.png", "categoria": "Calças", "cor_principal": "Preto",
        "ocasioes": ["Casual"], "estacoes": ["Verão"],
    }), 201)
    pasta = _ok(client.post(f"{API}/pastas", headers=h, json={"nome": "Trabalho"}), 201)
    look = _ok(client.post(f"{API}/looks", headers=h, json={
        "nome": "Look de teste", "peca_ids": [blusa["id"], calca["id"]], "ocasioes": ["Casual"],
    }), 201)
    _ok(client.patch(f"{API}/looks/{look['id']}", headers=h, json={"pasta_id": pasta["id"]}))
    uso = _ok(client.post(f"{API}/looks/{look['id']}/usos", headers=h, json={"usado_em": HOJE}), 201)
    colecao = _ok(client.post(f"{API}/colecoes", headers=h, json={"nome": "Verão"}), 201)
    referencia = _ok(client.post(
        f"{API}/referencias", headers=h,
        files={"arquivo": ("ref.png", _imagem())}, data={"colecao_id": colecao["id"], "nota": "inspiração"},
    ), 201)
    _ok(client.patch(f"{API}/referencias/{referencia['id']}", headers=h, json={
        "look_id": look["id"], "etiquetas": ["camiseta azul"],
    }))
    _ok(client.patch(f"{API}/preferencias", headers=h, json={"criatividade": 5, "estilos": ["Casual"]}))
    _ok(client.post(f"{API}/preferencias/pecas-evitadas", headers=h, json={"peca_id": blusa["id"]}), 201)
    combinacao = _ok(client.post(f"{API}/preferencias/combinacoes-evitadas", headers=h, json={
        "peca_a_id": blusa["id"], "peca_b_id": calca["id"],
    }), 201)
    return {
        "blusa": blusa["id"], "calca": calca["id"], "pasta": pasta["id"], "look": look["id"],
        "uso": uso["id"], "colecao": colecao["id"], "referencia": referencia["id"],
        "combinacao": combinacao["id"],
    }


def _estado(client, usuario) -> dict:
    """Tudo o que o usuário vê, por todas as listagens."""
    h = _como(usuario)
    rotas = {
        "pecas": f"{API}/pecas",
        "paradas": f"{API}/pecas/paradas?hoje={FUTURO}&limite=20",
        "looks": f"{API}/looks",
        "historico": f"{API}/looks/historico",
        "pastas": f"{API}/pastas",
        "colecoes": f"{API}/colecoes",
        "referencias": f"{API}/referencias",
        "preferencias": f"{API}/preferencias",
        "evitadas": f"{API}/preferencias/evitadas",
    }
    return {nome: _ok(client.get(rota, headers=h)) for nome, rota in rotas.items()}


@pytest.fixture
def mundo(client, usuarios):
    a, b = usuarios(), usuarios()
    dados_a = _criar_dados(client, a)
    # B tem os próprios recursos, para as tentativas de relação cruzada.
    b_peca = _ok(client.post(f"{API}/pecas", headers=_como(b), json={
        "imagem_url": "/uploads/b.png", "categoria": "Sapatos",
    }), 201)
    b_look = _ok(client.post(f"{API}/looks", headers=_como(b), json={"nome": "Do B", "peca_ids": [b_peca["id"]]}), 201)
    b_ref = _ok(client.post(f"{API}/referencias", headers=_como(b), files={"arquivo": ("b.png", _imagem())}), 201)
    return {
        "a": a, "b": b, "A": dados_a,
        "B": {"peca": b_peca["id"], "look": b_look["id"], "referencia": b_ref["id"]},
        "antes": _estado(client, a),
    }


def _ids_de_a(mundo) -> set[str]:
    return set(mundo["A"].values())


def _sem_dados_de_a(resposta, mundo):
    vazados = [i for i in _ids_de_a(mundo) if i in resposta.text]
    assert not vazados, f"{resposta.request.method} {resposta.request.url} mostrou ids de A: {vazados}"


# --- Listagens -----------------------------------------------------------------------


def test_a_ve_os_proprios_dados_em_todas_as_listagens(mundo):
    """Controle: sem isto, "B não vê nada" seria vazio de sentido."""
    antes, dados = mundo["antes"], mundo["A"]
    assert {p["id"] for p in antes["pecas"]} == {dados["blusa"], dados["calca"]}
    assert {p["peca"]["id"] for p in antes["paradas"]} == {dados["blusa"], dados["calca"]}
    assert [look["id"] for look in antes["looks"]] == [dados["look"]]
    assert [uso["id"] for uso in antes["historico"]] == [dados["uso"]]
    assert [p["id"] for p in antes["pastas"]] == [dados["pasta"]]
    assert [c["id"] for c in antes["colecoes"]] == [dados["colecao"]]
    assert [r["id"] for r in antes["referencias"]] == [dados["referencia"]]
    assert antes["preferencias"]["criatividade"] == 5
    assert [p["id"] for p in antes["evitadas"]["pecas"]] == [dados["blusa"]]
    assert [c["id"] for c in antes["evitadas"]["combinacoes"]] == [dados["combinacao"]]


LISTAGENS_DE_B = [
    ("GET", "/pecas", None),
    ("GET", "/pecas?limite=50&categoria=Camisetas&categoria=Calças", None),
    ("GET", "/pecas?outras=true&cor=Azul&ocasiao=Casual&estacao=Verão", None),
    ("GET", f"/pecas/paradas?hoje={FUTURO}&limite=20", None),
    ("GET", "/looks", None),
    ("GET", "/looks?sem_pasta=true", None),
    ("GET", "/looks/historico?limite=500", None),
    ("GET", "/pastas", None),
    ("GET", "/colecoes", None),
    ("GET", "/referencias", None),
    ("GET", "/referencias?sem_colecao=true", None),
    ("GET", "/preferencias", None),
    ("GET", "/preferencias/evitadas", None),
    ("POST", "/sugestoes", {}),
    ("POST", "/sugestoes", {"ocasiao": "Casual"}),
    ("POST", "/sugestoes/look-do-dia", {"data": HOJE}),
]


@pytest.mark.parametrize("metodo,rota,corpo", LISTAGENS_DE_B)
def test_listagens_de_b_nao_mostram_nada_de_a(client, mundo, metodo, rota, corpo):
    resposta = client.request(metodo, f"{API}{rota}", headers=_como(mundo["b"]), json=corpo)
    assert resposta.status_code == 200, resposta.text
    _sem_dados_de_a(resposta, mundo)


def test_contagem_e_preferencias_de_b_nao_refletem_a(client, mundo):
    resposta = client.get(f"{API}/pecas?categoria=Camisetas&categoria=Calças", headers=_como(mundo["b"]))
    assert resposta.headers["X-Total-Count"] == "0"
    # B nunca salvou preferências: recebe os padrões, não as de A.
    assert _ok(client.get(f"{API}/preferencias", headers=_como(mundo["b"])))["criatividade"] != 5


def test_filtrar_pela_colecao_de_a_nao_mostra_as_referencias_dela(client, mundo):
    resposta = client.get(f"{API}/referencias?colecao_id={mundo['A']['colecao']}", headers=_como(mundo["b"]))
    assert _ok(resposta) == []


# --- Ler, alterar e excluir recursos de A ----------------------------------------------

# (método, rota com {campos de A}, corpo)
TENTATIVAS_DIRETAS = [
    ("PUT", "/pecas/{blusa}", {"categoria": "Vestidos"}),
    ("DELETE", "/pecas/{blusa}", None),
    ("DELETE", "/pecas/{blusa}?remover_dos_looks=true", None),
    ("POST", "/pecas/{calca}/adiar-lembrete?hoje=" + HOJE, None),
    ("PATCH", "/looks/{look}", {"nome": "Roubado"}),
    ("PATCH", "/looks/{look}", {"favorito": True}),
    ("DELETE", "/looks/{look}", None),
    ("POST", "/looks/{look}/usos", {"usado_em": HOJE}),
    ("DELETE", "/looks/usos/{uso}", None),
    ("GET", "/looks?pasta_id={pasta}", None),
    ("PATCH", "/pastas/{pasta}", {"nome": "Roubada"}),
    ("DELETE", "/pastas/{pasta}", None),
    ("PATCH", "/colecoes/{colecao}", {"nome": "Roubada"}),
    ("DELETE", "/colecoes/{colecao}", None),
    ("PATCH", "/referencias/{referencia}", {"nota": "Roubada"}),
    ("PATCH", "/referencias/{referencia}", {"look_id": None, "colecao_id": None}),
    ("DELETE", "/referencias/{referencia}", None),
    ("POST", "/referencias/{referencia}/sugestao-de-look", None),
    ("DELETE", "/preferencias/pecas-evitadas/{blusa}", None),
    ("DELETE", "/preferencias/combinacoes-evitadas/{combinacao}", None),
]


@pytest.mark.parametrize("metodo,rota,corpo", TENTATIVAS_DIRETAS)
def test_b_nao_le_altera_nem_apaga_recurso_de_a(client, mundo, metodo, rota, corpo):
    resposta = client.request(
        metodo, f"{API}{rota.format(**mundo['A'])}", headers=_como(mundo["b"]), json=corpo
    )
    assert resposta.status_code == 404, f"{metodo} {rota}: {resposta.status_code} {resposta.text}"
    _sem_dados_de_a(resposta, mundo)
    assert _estado(client, mundo["a"]) == mundo["antes"]


# --- Relações cruzadas: B usando ids de A nos próprios recursos ------------------------

# (método, rota com {B_*}, corpo com {A_*}/{B_*})
RELACOES_CRUZADAS = [
    ("POST", "/looks", {"nome": "Com peça de A", "peca_ids": ["{A_blusa}"]}),
    ("POST", "/looks", {"nome": "Misturado", "peca_ids": ["{B_peca}", "{A_blusa}"]}),
    ("PATCH", "/looks/{B_look}", {"peca_ids": ["{A_blusa}"]}),
    ("PATCH", "/looks/{B_look}", {"pasta_id": "{A_pasta}"}),
    ("POST", "/preferencias/pecas-evitadas", {"peca_id": "{A_blusa}"}),
    ("POST", "/preferencias/combinacoes-evitadas", {"peca_a_id": "{B_peca}", "peca_b_id": "{A_blusa}"}),
    ("POST", "/preferencias/combinacoes-evitadas", {"peca_a_id": "{A_blusa}", "peca_b_id": "{A_calca}"}),
    ("POST", "/sugestoes", {"peca_base_id": "{A_blusa}"}),
    ("PATCH", "/referencias/{B_referencia}", {"colecao_id": "{A_colecao}"}),
    ("PATCH", "/referencias/{B_referencia}", {"look_id": "{A_look}"}),
]


def _preencher(valor, campos):
    if isinstance(valor, str):
        return valor.format(**campos)
    if isinstance(valor, list):
        return [_preencher(v, campos) for v in valor]
    if isinstance(valor, dict):
        return {k: _preencher(v, campos) for k, v in valor.items()}
    return valor


@pytest.mark.parametrize("metodo,rota,corpo", RELACOES_CRUZADAS)
def test_b_nao_liga_os_proprios_recursos_aos_de_a(client, mundo, metodo, rota, corpo):
    campos = {f"A_{k}": v for k, v in mundo["A"].items()} | {f"B_{k}": v for k, v in mundo["B"].items()}
    estado_b_antes = _estado(client, mundo["b"])

    resposta = client.request(
        metodo, f"{API}{_preencher(rota, campos)}", headers=_como(mundo["b"]), json=_preencher(corpo, campos)
    )

    assert resposta.status_code in (404, 422), f"{metodo} {rota}: {resposta.status_code} {resposta.text}"
    # Recusa como "não encontrado(a)(s)", sem dizer que o recurso existe.
    assert "encontrad" in resposta.text
    _sem_dados_de_a(resposta, mundo)
    assert _estado(client, mundo["b"]) == estado_b_antes
    assert _estado(client, mundo["a"]) == mundo["antes"]


def test_b_nao_cria_referencia_na_colecao_de_a(client, mundo):
    resposta = client.post(
        f"{API}/referencias", headers=_como(mundo["b"]),
        files={"arquivo": ("x.png", _imagem())}, data={"colecao_id": mundo["A"]["colecao"]},
    )
    assert resposta.status_code == 404, resposta.text
    assert _estado(client, mundo["a"]) == mundo["antes"]


def test_alteracoes_de_b_nas_proprias_coisas_nao_mexem_em_a(client, mundo):
    h = _como(mundo["b"])
    _ok(client.patch(f"{API}/preferencias", headers=h, json={"criatividade": 1, "estilos": ["Esportivo"]}))
    _ok(client.put(f"{API}/pecas/{mundo['B']['peca']}", headers=h, json={"categoria": "Acessórios"}))
    _ok(client.delete(f"{API}/looks/{mundo['B']['look']}", headers=h), 204)

    assert _estado(client, mundo["a"]) == mundo["antes"]
