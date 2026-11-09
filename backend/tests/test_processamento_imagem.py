"""E1.F1.5: rotas de processamento de imagem e o adaptador do rembg.

`POST /pecas/processar-imagem` e `POST /pecas/upload-original` não usam o banco,
então estes testes não pedem a fixture `usuarios` e rodam sem o Postgres. O
rembg é sempre simulado: nada aqui baixa o modelo U²-Net (~176 MB).

A E1.F1.7 (autenticação, tipo real e limite de tamanho) e a E10.F2.2 (Supabase
Storage) estendem este arquivo em vez de criar uma suíte paralela. O usuário
vem do cabeçalho `X-Usuario` (ver `conftest.py`).
"""

import logging
import uuid
from io import BytesIO
from pathlib import Path

import httpx
import pytest
from PIL import Image

from app.adapters import ollama_adapter, rembg_adapter
from app.core.config import settings
from fastapi.testclient import TestClient

from app.core.exceptions import ImagemInvalidaError, ProcessamentoImagemError
from app.main import app
from app.services.validacao_imagem import TAMANHO_MAX_BYTES
from app.schemas.peca import PecaBase

PROCESSAR = "/api/v1/pecas/processar-imagem"
ORIGINAL = "/api/v1/pecas/upload-original"
LOGGER_ROTA = "app.api.v1.pecas"
USUARIO = {"X-Usuario": str(uuid.uuid4())}


def _png(modo: str = "RGB", cor=(10, 120, 200)) -> bytes:
    buffer = BytesIO()
    Image.new(modo, (8, 8), cor).save(buffer, format="PNG")
    return buffer.getvalue()


def _arquivos_gravados() -> list[Path]:
    return [p for p in Path(settings.upload_dir).iterdir() if p.is_file()]


@pytest.fixture(autouse=True)
def sem_modelo_real(monkeypatch):
    """Se algum teste chegar ao `remove` real do rembg, falha em vez de baixar o modelo."""

    def proibido(*args, **kwargs):
        raise AssertionError("o rembg real não deve ser chamado nos testes")

    monkeypatch.setattr(rembg_adapter, "remove", proibido)
    monkeypatch.setattr(rembg_adapter, "_obter_sessao", lambda: None)


@pytest.fixture
def rembg_falso(monkeypatch):
    """Remoção de fundo simulada: devolve um PNG RGBA pequeno."""
    estado = {"saida": _png("RGBA", (0, 0, 0, 0)), "erro": None, "chamadas": 0}

    def falso(imagem_bytes: bytes) -> bytes:
        estado["chamadas"] += 1
        if estado["erro"] is not None:
            raise estado["erro"]
        return estado["saida"]

    monkeypatch.setattr(rembg_adapter, "remove_background", falso)
    return estado


@pytest.fixture
def sugestao_fixa(monkeypatch):
    sugestao = PecaBase(categoria="Camisetas", cor_principal="Azul")
    monkeypatch.setattr(ollama_adapter, "extract_metadata", lambda imagem_bytes: sugestao)
    return sugestao


# --- POST /pecas/processar-imagem


def test_processar_imagem_caminho_feliz(client, rembg_falso, sugestao_fixa):
    resposta = client.post(
        PROCESSAR, files={"arquivo": ("foto.png", _png(), "image/png")}, headers=USUARIO
    )

    assert resposta.status_code == 200
    corpo = resposta.json()
    assert corpo["imagem_url"].startswith("/uploads/")
    assert corpo["imagem_url"].endswith(".png")
    assert corpo["sugestao"]["categoria"] == "Camisetas"
    assert corpo["sugestao"]["cor_principal"] == "Azul"

    gravado = Path(settings.upload_dir) / Path(corpo["imagem_url"]).name
    assert gravado.read_bytes() == rembg_falso["saida"]
    assert rembg_falso["chamadas"] == 1


def test_processar_imagem_arquivo_invalido_responde_422(client, sugestao_fixa, caplog):
    # A validação (E1.F1.7) recusa o arquivo antes de chegar ao rembg.
    with caplog.at_level(logging.WARNING, logger=LOGGER_ROTA):
        resposta = client.post(
            PROCESSAR,
            files={"arquivo": ("foto.jpg", b"isto nao e uma imagem", "image/jpeg")},
            headers=USUARIO,
        )

    assert resposta.status_code == 422
    assert resposta.json()["detail"] == "O arquivo não é uma imagem válida."
    assert _arquivos_gravados() == []
    registros = [r for r in caplog.records if r.name == LOGGER_ROTA]
    assert any(r.levelno == logging.WARNING for r in registros)


def test_processar_imagem_falha_do_rembg_responde_500_generico(
    client, rembg_falso, sugestao_fixa, caplog
):
    causa = ProcessamentoImagemError("detalhe interno que não deve vazar")
    rembg_falso["erro"] = causa

    with caplog.at_level(logging.ERROR, logger=LOGGER_ROTA):
        resposta = client.post(
        PROCESSAR, files={"arquivo": ("foto.png", _png(), "image/png")}, headers=USUARIO
    )

    assert resposta.status_code == 500
    assert resposta.json() == {"detail": "Falha ao processar a imagem. Tente novamente."}
    assert "detalhe interno" not in resposta.text
    assert _arquivos_gravados() == []
    erros = [r for r in caplog.records if r.name == LOGGER_ROTA and r.levelno == logging.ERROR]
    assert len(erros) == 1
    assert erros[0].exc_info[1] is causa


def test_processar_imagem_com_ollama_fora_do_ar_devolve_sugestao_vazia(
    client, rembg_falso, monkeypatch
):
    def ollama_desligado(*args, **kwargs):
        raise httpx.ConnectError("conexão recusada")

    monkeypatch.setattr(ollama_adapter, "_conversar", ollama_desligado)

    resposta = client.post(
        PROCESSAR, files={"arquivo": ("foto.png", _png(), "image/png")}, headers=USUARIO
    )

    assert resposta.status_code == 200
    corpo = resposta.json()
    assert corpo["imagem_url"].startswith("/uploads/")
    assert corpo["sugestao"]["categoria"] == ""
    assert corpo["sugestao"]["cor_principal"] is None
    assert len(_arquivos_gravados()) == 1


# --- POST /pecas/upload-original


def test_upload_original_grava_os_bytes_enviados(client, rembg_falso):
    foto = _png(cor=(200, 30, 30))

    resposta = client.post(ORIGINAL, files={"arquivo": ("foto.png", foto, "image/png")}, headers=USUARIO)

    assert resposta.status_code == 200
    imagem_url = resposta.json()["imagem_url"]
    assert imagem_url.startswith("/uploads/")
    assert (Path(settings.upload_dir) / Path(imagem_url).name).read_bytes() == foto
    assert rembg_falso["chamadas"] == 0  # o fallback nunca passa pelo rembg


# --- E1.F1.7: autenticação, tipo real, tamanho e extensão segura


@pytest.fixture
def cliente_anonimo(tmp_path, monkeypatch):
    """Cliente sem a sobreposição de `get_current_user_id`: a autenticação é a real."""
    monkeypatch.setattr(settings, "upload_dir", str(tmp_path))
    app.dependency_overrides.clear()
    return TestClient(app)


@pytest.mark.parametrize("rota", [PROCESSAR, ORIGINAL])
def test_rotas_de_imagem_sem_token_respondem_401_e_nada_e_gravado(
    cliente_anonimo, rembg_falso, rota
):
    resposta = cliente_anonimo.post(rota, files={"arquivo": ("foto.png", _png(), "image/png")})

    assert resposta.status_code == 401
    assert rembg_falso["chamadas"] == 0
    assert _arquivos_gravados() == []


@pytest.mark.parametrize("rota", [PROCESSAR, ORIGINAL])
def test_texto_renomeado_para_png_responde_422_e_nada_e_gravado(client, rembg_falso, rota):
    resposta = client.post(
        rota, files={"arquivo": ("foto.png", b"so texto", "image/png")}, headers=USUARIO
    )

    assert resposta.status_code == 422
    assert resposta.json()["detail"] == "O arquivo não é uma imagem válida."
    assert rembg_falso["chamadas"] == 0
    assert _arquivos_gravados() == []


@pytest.mark.parametrize("rota", [PROCESSAR, ORIGINAL])
def test_gif_responde_422_com_mensagem_de_formato(client, rembg_falso, rota):
    buffer = BytesIO()
    Image.new("RGB", (8, 8), (1, 2, 3)).save(buffer, format="GIF")

    resposta = client.post(
        rota, files={"arquivo": ("foto.gif", buffer.getvalue(), "image/gif")}, headers=USUARIO
    )

    assert resposta.status_code == 422
    assert resposta.json()["detail"] == "Use uma imagem JPEG, PNG ou WebP."
    assert rembg_falso["chamadas"] == 0
    assert _arquivos_gravados() == []


@pytest.mark.parametrize("rota", [PROCESSAR, ORIGINAL])
def test_arquivo_acima_de_10_mb_responde_422_sem_chamar_o_rembg(client, rembg_falso, rota):
    grande = _png() + b"\0" * (TAMANHO_MAX_BYTES + 1)

    resposta = client.post(
        rota, files={"arquivo": ("foto.png", grande, "image/png")}, headers=USUARIO
    )

    assert resposta.status_code == 422
    assert resposta.json()["detail"] == "A imagem passa de 10 MB."
    assert rembg_falso["chamadas"] == 0
    assert _arquivos_gravados() == []


def test_upload_original_ignora_o_nome_e_grava_com_a_extensao_do_formato(client):
    foto = _png()

    resposta = client.post(
        ORIGINAL, files={"arquivo": ("foto.html", foto, "text/html")}, headers=USUARIO
    )

    assert resposta.status_code == 200
    imagem_url = resposta.json()["imagem_url"]
    assert imagem_url.startswith("/uploads/") and imagem_url.endswith(".png")
    assert (Path(settings.upload_dir) / Path(imagem_url).name).read_bytes() == foto


def test_upload_original_aceita_jpeg_e_webp(client):
    for formato, extensao in (("JPEG", ".jpg"), ("WEBP", ".webp")):
        buffer = BytesIO()
        Image.new("RGB", (8, 8), (9, 9, 9)).save(buffer, format=formato)

        resposta = client.post(
            ORIGINAL,
            files={"arquivo": ("qualquer", buffer.getvalue(), "application/octet-stream")},
            headers=USUARIO,
        )

        assert resposta.status_code == 200
        assert resposta.json()["imagem_url"].endswith(extensao)


# --- adaptador do rembg


def test_adaptador_bytes_que_nao_sao_imagem_levantam_imagem_invalida():
    with pytest.raises(ImagemInvalidaError) as erro:
        rembg_adapter.remove_background(b"nada de imagem aqui")

    assert erro.value.__cause__ is not None


def test_adaptador_falha_interna_do_rembg_levanta_processamento_com_causa(monkeypatch):
    causa = RuntimeError("onnx quebrou")

    def remove_quebrado(imagem, session=None):
        raise causa

    monkeypatch.setattr(rembg_adapter, "remove", remove_quebrado)

    with pytest.raises(ProcessamentoImagemError) as erro:
        rembg_adapter.remove_background(_png())

    assert erro.value.__cause__ is causa


def test_adaptador_devolve_png_do_resultado_do_rembg(monkeypatch):
    monkeypatch.setattr(
        rembg_adapter, "remove", lambda imagem, session=None: imagem.convert("RGBA")
    )

    saida = rembg_adapter.remove_background(_png())

    imagem = Image.open(BytesIO(saida))
    assert imagem.format == "PNG"
    assert imagem.mode == "RGBA"
