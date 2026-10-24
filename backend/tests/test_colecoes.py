"""Coleções do mural (E8.F2.1), contra o Postgres local (fixtures em
`conftest.py`; sem o banco no ar, os testes são pulados)."""

import io
import uuid

import pytest
from PIL import Image

COLECOES = "/api/v1/colecoes"
REFERENCIAS = "/api/v1/referencias"


def _como(usuario) -> dict:
    return {"X-Usuario": str(usuario)}


def _criar_colecao(client, usuario, nome="Festa"):
    return client.post(COLECOES, headers=_como(usuario), json={"nome": nome})


def _enviar(client, usuario, **dados):
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), "purple").save(buffer, format="PNG")
    return client.post(
        REFERENCIAS,
        headers=_como(usuario),
        files={"arquivo": ("look.png", buffer.getvalue())},
        data=dados,
    )


def _mover(client, usuario, referencia_id, colecao_id):
    return client.patch(
        f"{REFERENCIAS}/{referencia_id}", headers=_como(usuario), json={"colecao_id": colecao_id}
    )


def _ids(resposta) -> list[str]:
    return [item["id"] for item in resposta.json()]


def test_criar_aparece_na_lista_com_quantidade_zero_e_nome_sem_espacos(client, usuarios):
    eu = usuarios()
    criada = _criar_colecao(client, eu, "  Festa  ")

    assert criada.status_code == 201
    assert criada.json()["nome"] == "Festa"
    assert criada.json()["quantidade"] == 0
    lista = client.get(COLECOES, headers=_como(eu)).json()
    assert [(c["nome"], c["quantidade"]) for c in lista] == [("Festa", 0)]


@pytest.mark.parametrize("nome", ["", "   ", "a" * 41])
def test_nome_vazio_ou_grande_demais_da_422(client, usuarios, nome):
    assert _criar_colecao(client, usuarios(), nome).status_code == 422


def test_nome_repetido_da_409_mesmo_com_outra_caixa(client, usuarios):
    eu = usuarios()
    _criar_colecao(client, eu, "Festa")

    assert _criar_colecao(client, eu, "festa").status_code == 409
    assert _criar_colecao(client, eu, " FESTA ").status_code == 409
    assert len(client.get(COLECOES, headers=_como(eu)).json()) == 1


def test_mesmo_nome_em_usuarios_diferentes_e_permitido(client, usuarios):
    ana, bia = usuarios(), usuarios()
    assert _criar_colecao(client, ana, "Festa").status_code == 201
    assert _criar_colecao(client, bia, "Festa").status_code == 201


def test_lista_em_ordem_alfabetica_sem_diferenciar_caixa(client, usuarios):
    eu = usuarios()
    for nome in ["trabalho", "Academia", "festa"]:
        _criar_colecao(client, eu, nome)

    nomes = [c["nome"] for c in client.get(COLECOES, headers=_como(eu)).json()]
    assert nomes == ["Academia", "festa", "trabalho"]


def test_renomear_e_nome_repetido(client, usuarios):
    eu = usuarios()
    festa = _criar_colecao(client, eu, "Festa").json()
    _criar_colecao(client, eu, "Trabalho")

    renomeada = client.patch(f"{COLECOES}/{festa['id']}", headers=_como(eu), json={"nome": "Balada"})
    assert renomeada.status_code == 200
    assert renomeada.json()["nome"] == "Balada"
    # Trocar só a caixa do próprio nome é permitido.
    assert client.patch(f"{COLECOES}/{festa['id']}", headers=_como(eu), json={"nome": "BALADA"}).status_code == 200
    assert client.patch(f"{COLECOES}/{festa['id']}", headers=_como(eu), json={"nome": "trabalho"}).status_code == 409


def test_mover_referencia_atualiza_filtro_e_contagem(client, usuarios):
    eu = usuarios()
    festa = _criar_colecao(client, eu, "Festa").json()
    trabalho = _criar_colecao(client, eu, "Trabalho").json()
    a, b = _enviar(client, eu).json(), _enviar(client, eu).json()

    moveu = _mover(client, eu, a["id"], festa["id"])
    assert moveu.status_code == 200
    assert moveu.json()["colecao_id"] == festa["id"]
    _mover(client, eu, b["id"], trabalho["id"])

    na_festa = client.get(REFERENCIAS, headers=_como(eu), params={"colecao_id": festa["id"]})
    assert _ids(na_festa) == [a["id"]]
    quantidades = {c["nome"]: c["quantidade"] for c in client.get(COLECOES, headers=_como(eu)).json()}
    assert quantidades == {"Festa": 1, "Trabalho": 1}

    # Mover de novo: sai de uma e entra na outra.
    _mover(client, eu, a["id"], trabalho["id"])
    quantidades = {c["nome"]: c["quantidade"] for c in client.get(COLECOES, headers=_como(eu)).json()}
    assert quantidades == {"Festa": 0, "Trabalho": 2}


def test_filtro_sem_colecao_e_remover_da_colecao(client, usuarios):
    eu = usuarios()
    festa = _criar_colecao(client, eu).json()
    solta, guardada = _enviar(client, eu).json(), _enviar(client, eu).json()
    _mover(client, eu, guardada["id"], festa["id"])

    assert _ids(client.get(REFERENCIAS, headers=_como(eu), params={"sem_colecao": "true"})) == [solta["id"]]
    assert len(client.get(REFERENCIAS, headers=_como(eu)).json()) == 2

    tirou = _mover(client, eu, guardada["id"], None)
    assert tirou.json()["colecao_id"] is None
    assert len(client.get(REFERENCIAS, headers=_como(eu), params={"sem_colecao": "true"}).json()) == 2


def test_patch_so_da_nota_nao_mexe_na_colecao_e_vice_versa(client, usuarios):
    eu = usuarios()
    festa = _criar_colecao(client, eu).json()
    ref = _enviar(client, eu, nota="minha nota").json()
    _mover(client, eu, ref["id"], festa["id"])

    so_nota = client.patch(f"{REFERENCIAS}/{ref['id']}", headers=_como(eu), json={"nota": "outra"}).json()
    assert (so_nota["nota"], so_nota["colecao_id"]) == ("outra", festa["id"])
    so_colecao = _mover(client, eu, ref["id"], None).json()
    assert (so_colecao["nota"], so_colecao["colecao_id"]) == ("outra", None)


def test_filtrar_por_colecao_e_sem_colecao_juntos_da_422(client, usuarios):
    resposta = client.get(
        REFERENCIAS, headers=_como(usuarios()), params={"colecao_id": str(uuid.uuid4()), "sem_colecao": "true"}
    )
    assert resposta.status_code == 422


def test_enviar_ja_dentro_de_uma_colecao(client, usuarios):
    eu = usuarios()
    festa = _criar_colecao(client, eu).json()

    criada = _enviar(client, eu, colecao_id=festa["id"])
    assert criada.status_code == 201
    assert criada.json()["colecao_id"] == festa["id"]
    assert client.get(COLECOES, headers=_como(eu)).json()[0]["quantidade"] == 1


def test_excluir_colecao_mantem_as_referencias_sem_colecao(client, usuarios):
    eu = usuarios()
    festa = _criar_colecao(client, eu).json()
    ref = _enviar(client, eu, colecao_id=festa["id"]).json()

    assert client.delete(f"{COLECOES}/{festa['id']}", headers=_como(eu)).status_code == 204

    assert client.get(COLECOES, headers=_como(eu)).json() == []
    solta = client.get(REFERENCIAS, headers=_como(eu), params={"sem_colecao": "true"}).json()
    assert [r["id"] for r in solta] == [ref["id"]]
    assert solta[0]["colecao_id"] is None


def test_colecao_de_outro_usuario_da_404_em_tudo(client, usuarios):
    ana, bia = usuarios(), usuarios()
    da_ana = _criar_colecao(client, ana).json()
    ref_da_bia = _enviar(client, bia).json()

    assert client.get(COLECOES, headers=_como(bia)).json() == []
    assert client.patch(f"{COLECOES}/{da_ana['id']}", headers=_como(bia), json={"nome": "X"}).status_code == 404
    assert client.delete(f"{COLECOES}/{da_ana['id']}", headers=_como(bia)).status_code == 404
    # Nem mover para ela, nem enviar já dentro dela.
    assert _mover(client, bia, ref_da_bia["id"], da_ana["id"]).status_code == 404
    assert _enviar(client, bia, colecao_id=da_ana["id"]).status_code == 404
    # A coleção da Ana segue intacta e vazia.
    assert client.get(COLECOES, headers=_como(ana)).json()[0]["quantidade"] == 0


def test_colecao_inexistente_da_404(client, usuarios):
    eu = usuarios()
    inexistente = uuid.uuid4()
    assert client.patch(f"{COLECOES}/{inexistente}", headers=_como(eu), json={"nome": "X"}).status_code == 404
    assert client.delete(f"{COLECOES}/{inexistente}", headers=_como(eu)).status_code == 404


def test_erro_ao_enviar_para_colecao_de_outro_nao_salva_arquivo(client, usuarios, tmp_path):
    ana, bia = usuarios(), usuarios()
    da_ana = _criar_colecao(client, ana).json()

    assert _enviar(client, bia, colecao_id=da_ana["id"]).status_code == 404
    assert list(tmp_path.iterdir()) == []
