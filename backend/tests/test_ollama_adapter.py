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
