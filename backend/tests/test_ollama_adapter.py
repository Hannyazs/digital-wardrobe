import json

import httpx

from app.adapters import ollama_adapter


def _transport(conteudo, status=200):
    def handler(request: httpx.Request) -> httpx.Response:
        corpo = json.loads(request.content)
        assert request.url.path == "/api/chat"
        assert corpo["stream"] is False
        assert corpo["messages"][0]["images"]
        return httpx.Response(status, json={"message": {"content": conteudo}})

    return httpx.MockTransport(handler)


def _extrair(conteudo, status=200):
    return ollama_adapter.extract_metadata(b"img", transport=_transport(conteudo, status))


def test_sucesso():
    sugestao = _extrair(
        json.dumps(
            {
                "categoria": "Camisetas",
                "subcategoria": "gola V",
                "cor_principal": "Azul",
                "tonalidade_cor": "Vibrante",
            }
        )
    )
    assert sugestao.categoria == "Camisetas"
    assert sugestao.subcategoria == "gola V"
    assert sugestao.cor_principal == "Azul"
    assert sugestao.tonalidade_cor == "Vibrante"


def test_aceita_caixa_diferente():
    sugestao = _extrair(json.dumps({"categoria": "camisetas", "cor_principal": "AZUL"}))
    assert sugestao.categoria == "Camisetas"
    assert sugestao.cor_principal == "Azul"


def test_cor_fora_da_lista_vira_none_e_mantem_os_demais():
    sugestao = _extrair(
        json.dumps({"categoria": "Calças", "cor_principal": "Turquesa", "tonalidade_cor": "Escura"})
    )
    assert sugestao.categoria == "Calças"
    assert sugestao.cor_principal is None
    assert sugestao.tonalidade_cor == "Escura"


def test_categoria_fora_da_lista_vira_vazia():
    assert _extrair(json.dumps({"categoria": "Chapéus"})).categoria == ""


def test_subcategoria_que_repete_a_instrucao_e_descartada():
    assert _extrair(json.dumps({"categoria": "Camisas", "subcategoria": "texto curto"})).subcategoria is None


def test_subcategoria_limitada_a_40_caracteres():
    sugestao = _extrair(json.dumps({"categoria": "Camisas", "subcategoria": "a" * 100}))
    assert len(sugestao.subcategoria) == 40


def test_json_invalido_vira_sugestao_vazia():
    sugestao = _extrair("isto não é json")
    assert sugestao.categoria == ""
    assert sugestao.cor_principal is None


def test_json_que_nao_e_objeto_vira_sugestao_vazia():
    assert _extrair("[1, 2]").categoria == ""


def test_erro_http_vira_sugestao_vazia():
    assert _extrair("{}", status=500).categoria == ""


def test_conexao_recusada_vira_sugestao_vazia():
    def handler(request):
        raise httpx.ConnectError("recusada")

    sugestao = ollama_adapter.extract_metadata(b"img", transport=httpx.MockTransport(handler))
    assert sugestao.categoria == ""


def test_tempo_esgotado_vira_sugestao_vazia():
    def handler(request):
        raise httpx.ReadTimeout("lento")

    sugestao = ollama_adapter.extract_metadata(b"img", transport=httpx.MockTransport(handler))
    assert sugestao.categoria == ""


# --- E8.F4.1: peças visíveis numa referência do mural


def _etiquetar(conteudo, status=200):
    return ollama_adapter.listar_pecas_visiveis(b"img", transport=_transport(conteudo, status))


def test_pecas_visiveis_sucesso():
    etiquetas = _etiquetar(json.dumps({"pecas": ["camiseta branca", "calça jeans", "tênis preto"]}))

    assert etiquetas == ["camiseta branca", "calça jeans", "tênis preto"]


def test_pecas_visiveis_limpa_espacos_repetidas_e_itens_invalidos():
    etiquetas = _etiquetar(
        json.dumps({"pecas": ["  camiseta   branca ", "Camiseta Branca", "", "   ", 42, None, "bolsa"]})
    )

    assert etiquetas == ["camiseta branca", "bolsa"]


def test_pecas_visiveis_corta_em_40_caracteres_e_em_6_itens():
    muitas = [f"peça {i}" for i in range(10)]

    assert len(_etiquetar(json.dumps({"pecas": muitas}))) == 6
    assert len(_etiquetar(json.dumps({"pecas": ["a" * 100]}))[0]) == 40


def test_pecas_visiveis_descarta_eco_da_instrucao():
    etiquetas = _etiquetar(json.dumps({"pecas": ["peça e a cor, em poucas palavras", "saia plissada"]}))

    assert etiquetas == ["saia plissada"]


def test_pecas_visiveis_json_invalido_ou_formato_errado_vira_lista_vazia():
    assert _etiquetar("isto não é json") == []
    assert _etiquetar("[1, 2]") == []
    assert _etiquetar(json.dumps({"pecas": "camiseta"})) == []
    assert _etiquetar(json.dumps({})) == []


def test_pecas_visiveis_erro_http_conexao_e_tempo_esgotado_viram_lista_vazia():
    assert _etiquetar("{}", status=500) == []

    def recusa(request):
        raise httpx.ConnectError("recusada")

    def lento(request):
        raise httpx.ReadTimeout("lento")

    for handler in (recusa, lento):
        assert ollama_adapter.listar_pecas_visiveis(b"img", transport=httpx.MockTransport(handler)) == []


def test_pecas_visiveis_ignora_itens_de_cenario():
    etiquetas = _etiquetar(
        json.dumps(
            {
                "pecas": [
                    "chão de cascalho",
                    "Cascalho",
                    "pedra cinza",
                    "madeira clara",
                    "parede branca",
                    "Céu azul",
                    "grama verde",
                    "camiseta branca",
                    "calça jeans",
                ]
            }
        )
    )

    assert etiquetas == ["camiseta branca", "calça jeans"]


def test_pecas_visiveis_mantem_peca_feita_de_material_de_cenario():
    # O que vale é a primeira palavra: "bolsa de madeira" é uma peça.
    etiquetas = _etiquetar(json.dumps({"pecas": ["bolsa de madeira", "colar de pedra", "salto de madeira"]}))

    assert etiquetas == ["bolsa de madeira", "colar de pedra", "salto de madeira"]


def test_prompt_das_pecas_visiveis_pede_para_ignorar_o_ambiente():
    for termo in ("cascalho", "pedra", "madeira", "Ignore tudo que é cenário"):
        assert termo in ollama_adapter.PROMPT_PECAS_VISIVEIS


# --- E8.F5.2: comparar a referência com as peças candidatas


def _foto(tamanho=(1000, 800), cor=(200, 30, 30, 255), formato="PNG") -> bytes:
    import io

    from PIL import Image

    saida = io.BytesIO()
    Image.new("RGBA" if formato == "PNG" else "RGB", tamanho, cor if formato == "PNG" else cor[:3]).save(
        saida, format=formato
    )
    return saida.getvalue()


def _comparar(conteudo, candidatas=2, status=200):
    return ollama_adapter.escolher_peca_parecida(
        _foto(), "calça jeans azul", [_foto() for _ in range(candidatas)], transport=_transport(conteudo, status)
    )


def test_escolha_devolve_o_indice_a_partir_de_zero():
    assert _comparar(json.dumps({"escolha": 1})) == 0
    assert _comparar(json.dumps({"escolha": 2})) == 1
    assert _comparar(json.dumps({"escolha": 3}), candidatas=3) == 2


def test_escolha_zero_significa_nenhuma_peca_serve():
    assert _comparar(json.dumps({"escolha": 0})) is None


def test_escolha_invalida_vira_none():
    assert _comparar(json.dumps({"escolha": 3})) is None  # só há 2 candidatas
    assert _comparar(json.dumps({"escolha": -1})) is None
    assert _comparar(json.dumps({"escolha": "1"})) is None
    assert _comparar(json.dumps({"escolha": True})) is None
    assert _comparar(json.dumps({"escolha": 1.5})) is None
    assert _comparar(json.dumps({})) is None
    assert _comparar("isto não é json") is None
    assert _comparar("[1]") is None


def test_escolha_falha_de_rede_vira_none():
    assert _comparar("{}", status=500) is None

    def recusa(request):
        raise httpx.ConnectError("recusada")

    def lento(request):
        raise httpx.ReadTimeout("lento")

    for handler in (recusa, lento):
        resultado = ollama_adapter.escolher_peca_parecida(
            _foto(), "saia", [_foto()], transport=httpx.MockTransport(handler)
        )
        assert resultado is None


def test_escolha_sem_candidatas_nem_chama_o_ollama():
    def nao_deve_ser_chamado(request):
        raise AssertionError("o Ollama não deveria ser chamado")

    assert (
        ollama_adapter.escolher_peca_parecida(_foto(), "saia", [], transport=httpx.MockTransport(nao_deve_ser_chamado))
        is None
    )


def test_escolha_imagem_invalida_vira_none_sem_chamar_o_ollama():
    def nao_deve_ser_chamado(request):
        raise AssertionError("o Ollama não deveria ser chamado")

    resultado = ollama_adapter.escolher_peca_parecida(
        b"isto nao e uma imagem", "saia", [_foto()], transport=httpx.MockTransport(nao_deve_ser_chamado)
    )
    assert resultado is None


def test_escolha_envia_referencia_e_candidatas_reduzidas_com_o_pedido_certo():
    import base64
    import io

    from PIL import Image

    pedidos = []

    def handler(request):
        pedidos.append(json.loads(request.content))
        return httpx.Response(200, json={"message": {"content": json.dumps({"escolha": 2})}})

    referencia = _foto(tamanho=(2000, 1000))
    candidatas = [_foto(tamanho=(300, 300)), _foto(tamanho=(900, 1800))]
    resultado = ollama_adapter.escolher_peca_parecida(
        referencia, "tênis branco", candidatas, transport=httpx.MockTransport(handler)
    )

    assert resultado == 1
    corpo = pedidos[0]
    assert corpo["stream"] is False
    mensagem = corpo["messages"][0]
    # A primeira imagem é a referência; as outras, as candidatas, na ordem.
    assert len(mensagem["images"]) == 3
    for imagem in mensagem["images"]:
        with Image.open(io.BytesIO(base64.b64decode(imagem))) as aberta:
            assert aberta.format == "JPEG"
            assert max(aberta.size) <= 512
    with Image.open(io.BytesIO(base64.b64decode(mensagem["images"][1]))) as pequena:
        assert pequena.size == (300, 300)  # menor que o limite: não amplia
    # O pedido cita a peça e a quantidade de candidatas; a saída é limitada a 0..N.
    assert "tênis branco" in mensagem["content"]
    assert "de 1 a 2" in mensagem["content"]
    assert corpo["format"]["properties"]["escolha"]["maximum"] == 2
    assert corpo["format"]["properties"]["escolha"]["minimum"] == 0


def test_peca_com_fundo_transparente_vai_sobre_fundo_branco():
    import base64
    import io

    from PIL import Image

    pedidos = []

    def handler(request):
        pedidos.append(json.loads(request.content))
        return httpx.Response(200, json={"message": {"content": json.dumps({"escolha": 0})}})

    transparente = _foto(tamanho=(64, 64), cor=(0, 0, 0, 0))  # totalmente transparente
    ollama_adapter.escolher_peca_parecida(_foto(), "saia", [transparente], transport=httpx.MockTransport(handler))

    with Image.open(io.BytesIO(base64.b64decode(pedidos[0]["messages"][0]["images"][1]))) as imagem:
        r, g, b = imagem.convert("RGB").getpixel((10, 10))
    assert min(r, g, b) >= 250  # branco, não preto
