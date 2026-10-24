"""Rotas do mural de referências (E8.F1.1), contra o Postgres local (fixtures
em `conftest.py`; sem o banco no ar, os testes são pulados)."""

import io
import uuid

from fastapi.testclient import TestClient
from PIL import Image

from app.main import app

BASE = "/api/v1/referencias"


def _imagem(formato: str = "PNG") -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), "purple").save(buffer, format=formato)
    return buffer.getvalue()


def _enviar(client, usuario, conteudo: bytes, nome="look.png", **dados):
    return client.post(
        BASE,
        headers={"X-Usuario": str(usuario)},
        files={"arquivo": (nome, conteudo)},
        data=dados,
    )


def _como(usuario) -> dict:
    return {"X-Usuario": str(usuario)}


def test_criar_e_listar_mais_recentes_primeiro(client, usuarios, tmp_path):
    eu = usuarios()
    primeira = _enviar(client, eu, _imagem(), nota="  gostei das cores  ")
    segunda = _enviar(client, eu, _imagem("JPEG"), nome="foto.jpg")

    assert primeira.status_code == 201
    assert primeira.json()["nota"] == "gostei das cores"
    assert primeira.json()["imagem_url"].startswith("/uploads/")
    assert segunda.json()["imagem_url"].endswith(".jpg")
    assert segunda.json()["nota"] is None

    lista = client.get(BASE, headers=_como(eu)).json()
    assert [r["id"] for r in lista] == [segunda.json()["id"], primeira.json()["id"]]
    # O arquivo foi salvo de verdade.
    assert len(list(tmp_path.iterdir())) == 2


def test_arquivo_que_nao_e_imagem_e_recusado_e_nada_e_salvo(client, usuarios, tmp_path):
    eu = usuarios()
    resposta = _enviar(client, eu, b"isto nao e uma imagem", nome="x.png")

    assert resposta.status_code == 422
    assert client.get(BASE, headers=_como(eu)).json() == []
    assert list(tmp_path.iterdir()) == []


def test_formato_nao_aceito_e_recusado(client, usuarios):
    assert _enviar(client, usuarios(), _imagem("GIF"), nome="a.gif").status_code == 422


def test_imagem_acima_de_10_mb_e_recusada(client, usuarios, tmp_path):
    resposta = _enviar(client, usuarios(), b"0" * (10 * 1024 * 1024 + 1))

    assert resposta.status_code == 422
    assert list(tmp_path.iterdir()) == []


def test_nota_acima_de_500_caracteres_e_recusada(client, usuarios):
    assert _enviar(client, usuarios(), _imagem(), nota="a" * 501).status_code == 422


def test_editar_nota_e_limpar_com_vazio(client, usuarios):
    eu = usuarios()
    criada = _enviar(client, eu, _imagem()).json()

    editada = client.patch(f"{BASE}/{criada['id']}", headers=_como(eu), json={"nota": " festa de formatura "})
    assert editada.status_code == 200
    assert editada.json()["nota"] == "festa de formatura"

    limpa = client.patch(f"{BASE}/{criada['id']}", headers=_como(eu), json={"nota": "   "})
    assert limpa.json()["nota"] is None
    assert client.get(BASE, headers=_como(eu)).json()[0]["nota"] is None


def test_excluir_remove_registro_e_arquivo(client, usuarios, tmp_path):
    eu = usuarios()
    criada = _enviar(client, eu, _imagem()).json()
    assert len(list(tmp_path.iterdir())) == 1

    assert client.delete(f"{BASE}/{criada['id']}", headers=_como(eu)).status_code == 204
    assert client.get(BASE, headers=_como(eu)).json() == []
    assert list(tmp_path.iterdir()) == []


def test_excluir_com_arquivo_ja_apagado_nao_da_erro(client, usuarios, tmp_path):
    eu = usuarios()
    criada = _enviar(client, eu, _imagem()).json()
    for arquivo in tmp_path.iterdir():
        arquivo.unlink()

    assert client.delete(f"{BASE}/{criada['id']}", headers=_como(eu)).status_code == 204


def test_cada_usuario_ve_edita_e_exclui_so_as_suas(client, usuarios, tmp_path):
    ana, bia = usuarios(), usuarios()
    da_ana = _enviar(client, ana, _imagem()).json()

    assert client.get(BASE, headers=_como(bia)).json() == []
    assert client.patch(f"{BASE}/{da_ana['id']}", headers=_como(bia), json={"nota": "x"}).status_code == 404
    assert client.delete(f"{BASE}/{da_ana['id']}", headers=_como(bia)).status_code == 404
    # Nada mudou para a dona.
    assert [r["id"] for r in client.get(BASE, headers=_como(ana)).json()] == [da_ana["id"]]
    assert len(list(tmp_path.iterdir())) == 1


def test_referencia_inexistente_da_404(client, usuarios):
    eu = usuarios()
    inexistente = uuid.uuid4()
    assert client.patch(f"{BASE}/{inexistente}", headers=_como(eu), json={"nota": "x"}).status_code == 404
    assert client.delete(f"{BASE}/{inexistente}", headers=_como(eu)).status_code == 404


def test_sem_token_a_rota_exige_autenticacao():
    # Sem os overrides: o token é obrigatório.
    assert TestClient(app).get(BASE).status_code in (401, 403)


# --- E8.F3.1: ligar a referência a um look salvo ---


def _criar_look(client, usuario, nome="Look de sexta") -> dict:
    peca = client.post(
        "/api/v1/pecas",
        headers={"X-Usuario": str(usuario)},
        json={"imagem_url": "/uploads/x.png", "categoria": "Camisetas"},
    ).json()
    return client.post(
        "/api/v1/looks",
        headers={"X-Usuario": str(usuario)},
        json={"nome": nome, "peca_ids": [peca["id"]]},
    ).json()


def _ligar(client, usuario, referencia_id, look_id):
    return client.patch(
        f"{BASE}/{referencia_id}", headers={"X-Usuario": str(usuario)}, json={"look_id": look_id}
    )


def test_sem_look_a_referencia_vem_com_look_nulo(client, usuarios):
    eu = usuarios()
    assert _enviar(client, eu, _imagem()).json()["look"] is None


def test_ligar_a_um_look_mostra_o_look_na_resposta_e_na_lista(client, usuarios):
    eu = usuarios()
    look = _criar_look(client, eu)
    ref = _enviar(client, eu, _imagem()).json()

    ligada = _ligar(client, eu, ref["id"], look["id"])

    assert ligada.status_code == 200
    assert ligada.json()["look"] == {"id": look["id"], "nome": "Look de sexta"}
    assert client.get(BASE, headers={"X-Usuario": str(eu)}).json()[0]["look"]["id"] == look["id"]


def test_um_look_pode_ter_varias_referencias(client, usuarios):
    eu = usuarios()
    look = _criar_look(client, eu)
    a, b = _enviar(client, eu, _imagem()).json(), _enviar(client, eu, _imagem()).json()

    assert _ligar(client, eu, a["id"], look["id"]).status_code == 200
    assert _ligar(client, eu, b["id"], look["id"]).status_code == 200
    ligados = [r["look"]["id"] for r in client.get(BASE, headers={"X-Usuario": str(eu)}).json()]
    assert ligados == [look["id"], look["id"]]


def test_desligar_volta_a_referencia_para_sem_look(client, usuarios):
    eu = usuarios()
    look = _criar_look(client, eu)
    ref = _enviar(client, eu, _imagem()).json()
    _ligar(client, eu, ref["id"], look["id"])

    desligada = _ligar(client, eu, ref["id"], None)

    assert desligada.status_code == 200
    assert desligada.json()["look"] is None


def test_ligar_o_look_nao_mexe_na_nota_nem_na_colecao(client, usuarios):
    eu = usuarios()
    look = _criar_look(client, eu)
    colecao = client.post("/api/v1/colecoes", headers={"X-Usuario": str(eu)}, json={"nome": "Festa"}).json()
    ref = _enviar(client, eu, _imagem(), nota="minha nota", colecao_id=colecao["id"]).json()

    ligada = _ligar(client, eu, ref["id"], look["id"]).json()

    assert (ligada["nota"], ligada["colecao_id"]) == ("minha nota", colecao["id"])


def test_look_arquivado_aparece_como_sem_look(client, usuarios):
    eu = usuarios()
    look = _criar_look(client, eu)
    ref = _enviar(client, eu, _imagem()).json()
    _ligar(client, eu, ref["id"], look["id"])

    assert client.delete(f"/api/v1/looks/{look['id']}", headers={"X-Usuario": str(eu)}).status_code == 204

    assert client.get(BASE, headers={"X-Usuario": str(eu)}).json()[0]["look"] is None


def test_nao_liga_a_look_arquivado_nem_de_outro_usuario_nem_inexistente(client, usuarios):
    ana, bia = usuarios(), usuarios()
    da_ana = _criar_look(client, ana)
    arquivado = _criar_look(client, bia, "Velho")
    client.delete(f"/api/v1/looks/{arquivado['id']}", headers={"X-Usuario": str(bia)})
    ref_da_bia = _enviar(client, bia, _imagem()).json()

    assert _ligar(client, bia, ref_da_bia["id"], da_ana["id"]).status_code == 404
    assert _ligar(client, bia, ref_da_bia["id"], arquivado["id"]).status_code == 404
    assert _ligar(client, bia, ref_da_bia["id"], str(uuid.uuid4())).status_code == 404
    assert client.get(BASE, headers={"X-Usuario": str(bia)}).json()[0]["look"] is None


# --- E8.F4.1: etiquetas das peças visíveis (sugeridas pela IA, editáveis)


def _patch(client, usuario, referencia_id, corpo):
    return client.patch(f"{BASE}/{referencia_id}", headers={"X-Usuario": str(usuario)}, json=corpo)


def test_referencia_nasce_com_as_etiquetas_sugeridas_pela_ia(client, usuarios, etiquetas_da_ia):
    etiquetas_da_ia["valor"] = ["camiseta branca", "calça jeans"]
    eu = usuarios()

    criada = _enviar(client, eu, _imagem())

    assert criada.status_code == 201
    assert criada.json()["etiquetas"] == ["camiseta branca", "calça jeans"]
    assert client.get(BASE, headers={"X-Usuario": str(eu)}).json()[0]["etiquetas"] == [
        "camiseta branca",
        "calça jeans",
    ]
    assert etiquetas_da_ia["chamadas"] == 1


def test_sem_ia_a_referencia_e_salva_sem_etiquetas(client, usuarios, etiquetas_da_ia):
    etiquetas_da_ia["erro"] = RuntimeError("ollama fora do ar")
    eu = usuarios()

    criada = _enviar(client, eu, _imagem())

    assert criada.status_code == 201
    assert criada.json()["etiquetas"] == []


def test_imagem_invalida_nao_chama_a_ia(client, usuarios, etiquetas_da_ia):
    assert _enviar(client, usuarios(), b"isto nao e uma imagem", nome="x.png").status_code == 422
    assert etiquetas_da_ia["chamadas"] == 0


def test_editar_as_etiquetas_troca_a_lista_inteira(client, usuarios, etiquetas_da_ia):
    etiquetas_da_ia["valor"] = ["camiseta branca", "calça jeans"]
    eu = usuarios()
    ref = _enviar(client, eu, _imagem()).json()

    editada = _patch(client, eu, ref["id"], {"etiquetas": ["  camiseta   azul ", "Camiseta Azul", "tênis", ""]})

    assert editada.status_code == 200
    assert editada.json()["etiquetas"] == ["camiseta azul", "tênis"]
    assert _patch(client, eu, ref["id"], {"etiquetas": []}).json()["etiquetas"] == []


def test_etiquetas_invalidas_dao_422(client, usuarios):
    eu = usuarios()
    ref = _enviar(client, eu, _imagem()).json()

    assert _patch(client, eu, ref["id"], {"etiquetas": [f"peça {i}" for i in range(11)]}).status_code == 422
    assert _patch(client, eu, ref["id"], {"etiquetas": ["a" * 41]}).status_code == 422
    assert _patch(client, eu, ref["id"], {"etiquetas": None}).status_code == 422


def test_mexer_na_nota_nao_apaga_as_etiquetas(client, usuarios, etiquetas_da_ia):
    etiquetas_da_ia["valor"] = ["saia plissada"]
    eu = usuarios()
    ref = _enviar(client, eu, _imagem()).json()

    nova = _patch(client, eu, ref["id"], {"nota": "gostei"}).json()

    assert (nova["nota"], nova["etiquetas"]) == ("gostei", ["saia plissada"])


# --- E8.F5.2: sugestão de look a partir da referência

SUGESTAO = "sugestao-de-look"


def _peca_com_foto(client, usuario, categoria, cor=None, subcategoria=None) -> dict:
    """Peça com a foto de verdade na pasta de uploads do teste (a sugestão lê o arquivo)."""
    import pathlib

    from app.core.config import settings

    nome = f"{uuid.uuid4()}.png"
    (pathlib.Path(settings.upload_dir) / nome).write_bytes(_imagem())
    return client.post(
        "/api/v1/pecas",
        headers={"X-Usuario": str(usuario)},
        json={
            "imagem_url": f"/uploads/{nome}",
            "categoria": categoria,
            "cor_principal": cor,
            "subcategoria": subcategoria,
        },
    ).json()


def _referencia_com(client, usuario, etiquetas_da_ia, etiquetas) -> dict:
    etiquetas_da_ia["valor"] = etiquetas
    return _enviar(client, usuario, _imagem()).json()


def _sugerir(client, usuario, referencia_id):
    return client.post(f"{BASE}/{referencia_id}/{SUGESTAO}", headers={"X-Usuario": str(usuario)})


def test_sugestao_de_look_novo_com_lacunas_e_so_pecas_do_usuario(client, usuarios, etiquetas_da_ia, escolha_da_ia):
    eu, outra = usuarios(), usuarios()
    calca = _peca_com_foto(client, eu, "Calças", "Azul", "jeans")
    tenis = _peca_com_foto(client, eu, "Sapatos", "Branco")
    _peca_com_foto(client, outra, "Acessórios", "Preto")  # de outra pessoa: nunca aparece
    ref = _referencia_com(client, eu, etiquetas_da_ia, ["calça jeans azul", "tênis branco", "bolsa preta"])

    resposta = _sugerir(client, eu, ref["id"])

    assert resposta.status_code == 200
    corpo = resposta.json()
    assert corpo["tipo"] == "look_novo"
    assert corpo["look"] is None
    assert {p["id"] for p in corpo["pecas"]} == {calca["id"], tenis["id"]}
    assert [(i["etiqueta"], i["situacao"]) for i in corpo["itens"]] == [
        ("calça jeans azul", "encontrada"),
        ("tênis branco", "encontrada"),
        ("bolsa preta", "sem_peca_equivalente"),
    ]
    assert corpo["itens"][0]["peca"]["id"] == calca["id"]
    assert corpo["itens"][2]["peca"] is None
    assert corpo["lacunas"] == ["bolsa preta"]
    # A bolsa não tinha candidata no armário dela: a IA nem foi chamada para ela.
    assert [etiqueta for etiqueta, _ in escolha_da_ia["chamadas"]] == ["calça jeans azul", "tênis branco"]


def test_sugestao_aponta_o_look_salvo_que_contem_as_pecas(client, usuarios, etiquetas_da_ia, escolha_da_ia):
    eu = usuarios()
    calca = _peca_com_foto(client, eu, "Calças", "Azul")
    tenis = _peca_com_foto(client, eu, "Sapatos", "Branco")
    camiseta = _peca_com_foto(client, eu, "Camisetas", "Branco")
    look = client.post(
        "/api/v1/looks",
        headers={"X-Usuario": str(eu)},
        json={"nome": "Look de sexta", "peca_ids": [calca["id"], tenis["id"], camiseta["id"]]},
    ).json()
    ref = _referencia_com(client, eu, etiquetas_da_ia, ["calça azul", "tênis branco"])

    corpo = _sugerir(client, eu, ref["id"]).json()

    assert corpo["tipo"] == "look_salvo"
    assert corpo["look"]["id"] == look["id"]
    assert corpo["look"]["nome"] == "Look de sexta"
    assert len(corpo["look"]["pecas"]) == 3
    assert {p["id"] for p in corpo["pecas"]} == {calca["id"], tenis["id"]}


def test_look_arquivado_nao_e_sugerido(client, usuarios, etiquetas_da_ia, escolha_da_ia):
    eu = usuarios()
    calca = _peca_com_foto(client, eu, "Calças", "Azul")
    tenis = _peca_com_foto(client, eu, "Sapatos", "Branco")
    look = client.post(
        "/api/v1/looks", headers={"X-Usuario": str(eu)}, json={"nome": "Velho", "peca_ids": [calca["id"], tenis["id"]]}
    ).json()
    client.delete(f"/api/v1/looks/{look['id']}", headers={"X-Usuario": str(eu)})
    ref = _referencia_com(client, eu, etiquetas_da_ia, ["calça azul", "tênis branco"])

    assert _sugerir(client, eu, ref["id"]).json()["tipo"] == "look_novo"


def test_sem_etiquetas_da_422_e_nao_chama_a_ia(client, usuarios, escolha_da_ia):
    eu = usuarios()
    ref = _enviar(client, eu, _imagem()).json()

    resposta = _sugerir(client, eu, ref["id"])

    assert resposta.status_code == 422
    assert "etiquetas" in resposta.json()["detail"]
    assert escolha_da_ia["chamadas"] == []


def test_referencia_de_outro_usuario_ou_inexistente_da_404(client, usuarios, etiquetas_da_ia):
    ana, bia = usuarios(), usuarios()
    ref = _referencia_com(client, ana, etiquetas_da_ia, ["calça azul"])

    assert _sugerir(client, bia, ref["id"]).status_code == 404
    assert _sugerir(client, ana, str(uuid.uuid4())).status_code == 404


def test_peca_evitada_nunca_e_candidata(client, usuarios, etiquetas_da_ia, escolha_da_ia):
    eu = usuarios()
    evitada = _peca_com_foto(client, eu, "Calças", "Azul", "jeans")
    client.post("/api/v1/preferencias/pecas-evitadas", headers={"X-Usuario": str(eu)}, json={"peca_id": evitada["id"]})
    ref = _referencia_com(client, eu, etiquetas_da_ia, ["calça jeans azul"])

    corpo = _sugerir(client, eu, ref["id"]).json()

    assert corpo["tipo"] == "sem_pecas"
    assert corpo["lacunas"] == ["calça jeans azul"]
    assert escolha_da_ia["chamadas"] == []


def test_com_a_ia_parada_a_resposta_e_200_sem_pecas(client, usuarios, etiquetas_da_ia, escolha_da_ia):
    eu = usuarios()
    _peca_com_foto(client, eu, "Calças", "Azul")
    ref = _referencia_com(client, eu, etiquetas_da_ia, ["calça azul"])
    escolha_da_ia["decidir"] = lambda etiqueta, quantidade: None  # é o que o adaptador devolve se o Ollama cai

    resposta = _sugerir(client, eu, ref["id"])

    assert resposta.status_code == 200
    corpo = resposta.json()
    assert corpo["tipo"] == "sem_pecas"
    assert corpo["itens"][0]["situacao"] == "sem_peca_equivalente"
    assert corpo["lacunas"] == ["calça azul"]


def test_foto_da_referencia_sumida_da_404(client, usuarios, etiquetas_da_ia, tmp_path):
    eu = usuarios()
    ref = _referencia_com(client, eu, etiquetas_da_ia, ["calça azul"])
    for arquivo in tmp_path.iterdir():
        arquivo.unlink()

    resposta = _sugerir(client, eu, ref["id"])

    assert resposta.status_code == 404
    assert "imagem da referência" in resposta.json()["detail"]


def test_sugerir_nao_grava_nada(client, usuarios, etiquetas_da_ia, escolha_da_ia):
    eu = usuarios()
    _peca_com_foto(client, eu, "Calças", "Azul")
    _peca_com_foto(client, eu, "Sapatos", "Branco")
    ref = _referencia_com(client, eu, etiquetas_da_ia, ["calça azul", "tênis branco"])

    _sugerir(client, eu, ref["id"])

    assert client.get("/api/v1/looks", headers={"X-Usuario": str(eu)}).json() == []
    guardada = client.get(BASE, headers={"X-Usuario": str(eu)}).json()[0]
    assert guardada["look"] is None
    assert guardada["etiquetas"] == ["calça azul", "tênis branco"]
