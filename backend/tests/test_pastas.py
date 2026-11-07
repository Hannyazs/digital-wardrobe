"""Pastas de looks (E3.F6.1), contra o Postgres local (fixtures em
`conftest.py`; sem o banco no ar, os testes de rota são pulados)."""

import uuid

import pytest
from pydantic import ValidationError

from app.schemas.look import LookUpdate

PASTAS = "/api/v1/pastas"
LOOKS = "/api/v1/looks"
PECAS = "/api/v1/pecas"


def _como(usuario) -> dict:
    return {"X-Usuario": str(usuario)}


def _criar_pasta(client, usuario, nome="Trabalho"):
    return client.post(PASTAS, headers=_como(usuario), json={"nome": nome})


def _pasta(client, usuario, nome="Trabalho") -> dict:
    resposta = _criar_pasta(client, usuario, nome)
    assert resposta.status_code == 201, resposta.text
    return resposta.json()


def _look(client, usuario, nome="Look") -> dict:
    peca = client.post(PECAS, headers=_como(usuario), json={"imagem_url": "/uploads/x.png", "categoria": "Camisetas"})
    assert peca.status_code == 201, peca.text
    look = client.post(LOOKS, headers=_como(usuario), json={"nome": nome, "peca_ids": [peca.json()["id"]]})
    assert look.status_code == 201, look.text
    return look.json()


def _mover(client, usuario, look_id, pasta_id):
    return client.patch(f"{LOOKS}/{look_id}", headers=_como(usuario), json={"pasta_id": pasta_id})


def _pastas(client, usuario) -> list[dict]:
    resposta = client.get(PASTAS, headers=_como(usuario))
    assert resposta.status_code == 200, resposta.text
    return resposta.json()


def _looks(client, usuario, **params):
    return client.get(LOOKS, headers=_como(usuario), params=params)


def _ids(resposta) -> set[str]:
    assert resposta.status_code == 200, resposta.text
    return {look["id"] for look in resposta.json()}


# --- Schema (sem banco) -----------------------------------------------------------


def test_pasta_id_aceita_null_mas_os_outros_campos_continuam_nao_nulos():
    assert LookUpdate.model_validate({"pasta_id": None}).model_dump(exclude_unset=True) == {"pasta_id": None}
    for campo in ("nome", "favorito", "ocasioes", "peca_ids"):
        with pytest.raises(ValidationError):
            LookUpdate.model_validate({campo: None})


# --- Rotas -------------------------------------------------------------------------


def test_criar_pasta_aparece_com_quantidade_zero(client, usuarios):
    eu = usuarios()
    criada = _pasta(client, eu, "  Viagem à praia  ")

    assert criada["nome"] == "Viagem à praia"
    assert [(p["nome"], p["quantidade"]) for p in _pastas(client, eu)] == [("Viagem à praia", 0)]


@pytest.mark.parametrize("nome", ["", "   ", "x" * 41])
def test_nome_vazio_ou_longo_da_422(client, usuarios, nome):
    assert _criar_pasta(client, usuarios(), nome).status_code == 422


def test_nome_repetido_mesmo_com_outra_caixa_da_409(client, usuarios):
    eu = usuarios()
    _pasta(client, eu, "Trabalho")

    assert _criar_pasta(client, eu, "TRABALHO").status_code == 409
    # Outro usuário pode usar o mesmo nome.
    assert _criar_pasta(client, usuarios(), "Trabalho").status_code == 201


def test_lista_em_ordem_alfabetica(client, usuarios):
    eu = usuarios()
    for nome in ["viagem", "Academia", "Trabalho"]:
        _pasta(client, eu, nome)

    assert [p["nome"] for p in _pastas(client, eu)] == ["Academia", "Trabalho", "viagem"]


def test_renomear_e_conflito_ao_renomear(client, usuarios):
    eu = usuarios()
    trabalho = _pasta(client, eu, "Trabalho")
    _pasta(client, eu, "Festa")
    look = _look(client, eu)
    _mover(client, eu, look["id"], trabalho["id"])

    renomeada = client.patch(f"{PASTAS}/{trabalho['id']}", headers=_como(eu), json={"nome": "Escritório"})
    assert renomeada.status_code == 200
    assert (renomeada.json()["nome"], renomeada.json()["quantidade"]) == ("Escritório", 1)

    conflito = client.patch(f"{PASTAS}/{trabalho['id']}", headers=_como(eu), json={"nome": "festa"})
    assert conflito.status_code == 409
    # Renomear para o próprio nome com outra caixa não é conflito.
    assert client.patch(f"{PASTAS}/{trabalho['id']}", headers=_como(eu), json={"nome": "ESCRITÓRIO"}).status_code == 200


def test_mover_look_lista_na_pasta_e_sobe_a_contagem(client, usuarios):
    eu = usuarios()
    pasta = _pasta(client, eu)
    dentro, fora = _look(client, eu, "Dentro"), _look(client, eu, "Fora")

    resposta = _mover(client, eu, dentro["id"], pasta["id"])

    assert resposta.status_code == 200
    assert resposta.json()["pasta_id"] == pasta["id"]
    assert _ids(_looks(client, eu, pasta_id=pasta["id"])) == {dentro["id"]}
    assert _ids(_looks(client, eu, sem_pasta="true")) == {fora["id"]}
    assert _ids(_looks(client, eu)) == {dentro["id"], fora["id"]}
    assert _pastas(client, eu)[0]["quantidade"] == 1


def test_mover_de_uma_pasta_para_outra(client, usuarios):
    eu = usuarios()
    a, b = _pasta(client, eu, "A"), _pasta(client, eu, "B")
    look = _look(client, eu)

    _mover(client, eu, look["id"], a["id"])
    _mover(client, eu, look["id"], b["id"])

    assert [(p["nome"], p["quantidade"]) for p in _pastas(client, eu)] == [("A", 0), ("B", 1)]


def test_pasta_id_null_tira_o_look_da_pasta(client, usuarios):
    eu = usuarios()
    pasta = _pasta(client, eu)
    look = _look(client, eu)
    _mover(client, eu, look["id"], pasta["id"])

    resposta = _mover(client, eu, look["id"], None)

    assert resposta.status_code == 200
    assert resposta.json()["pasta_id"] is None
    assert _ids(_looks(client, eu, sem_pasta="true")) == {look["id"]}
    assert _pastas(client, eu)[0]["quantidade"] == 0


def test_patch_sem_pasta_id_nao_mexe_na_pasta(client, usuarios):
    eu = usuarios()
    pasta = _pasta(client, eu)
    look = _look(client, eu)
    _mover(client, eu, look["id"], pasta["id"])

    resposta = client.patch(f"{LOOKS}/{look['id']}", headers=_como(eu), json={"favorito": True})

    assert resposta.json()["pasta_id"] == pasta["id"]


def test_excluir_pasta_mantem_os_looks_sem_pasta(client, usuarios):
    eu = usuarios()
    pasta = _pasta(client, eu)
    look = _look(client, eu)
    _mover(client, eu, look["id"], pasta["id"])

    assert client.delete(f"{PASTAS}/{pasta['id']}", headers=_como(eu)).status_code == 204

    assert _pastas(client, eu) == []
    assert _ids(_looks(client, eu, sem_pasta="true")) == {look["id"]}


def test_look_arquivado_nao_conta_na_quantidade(client, usuarios):
    eu = usuarios()
    pasta = _pasta(client, eu)
    ativo, arquivado = _look(client, eu), _look(client, eu)
    for look in (ativo, arquivado):
        _mover(client, eu, look["id"], pasta["id"])
    assert client.delete(f"{LOOKS}/{arquivado['id']}", headers=_como(eu)).status_code == 204

    assert _pastas(client, eu)[0]["quantidade"] == 1
    assert _ids(_looks(client, eu, pasta_id=pasta["id"])) == {ativo["id"]}


def test_pasta_id_e_sem_pasta_juntos_dao_422(client, usuarios):
    eu = usuarios()
    pasta = _pasta(client, eu)
    assert _looks(client, eu, pasta_id=pasta["id"], sem_pasta="true").status_code == 422


def test_pasta_de_outro_usuario_da_404_em_todas_as_rotas(client, usuarios):
    eu, outra = usuarios(), usuarios()
    dela = _pasta(client, outra, "Dela")
    meu_look = _look(client, eu)

    assert client.patch(f"{PASTAS}/{dela['id']}", headers=_como(eu), json={"nome": "Minha"}).status_code == 404
    assert client.delete(f"{PASTAS}/{dela['id']}", headers=_como(eu)).status_code == 404
    assert _looks(client, eu, pasta_id=dela["id"]).status_code == 404
    assert _mover(client, eu, meu_look["id"], dela["id"]).status_code == 404
    assert _pastas(client, eu) == []
    # Nada mudou do lado dela.
    assert [(p["nome"], p["quantidade"]) for p in _pastas(client, outra)] == [("Dela", 0)]


def test_pasta_inexistente_da_404(client, usuarios):
    eu = usuarios()
    inexistente = str(uuid.uuid4())
    look = _look(client, eu)

    assert client.delete(f"{PASTAS}/{inexistente}", headers=_como(eu)).status_code == 404
    assert _mover(client, eu, look["id"], inexistente).status_code == 404
