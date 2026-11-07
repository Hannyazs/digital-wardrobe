"""Remoção de fundo das fotos de peças, via rembg.

Isolado em adapter porque é a etapa mais provável de trocar (ex: por um
serviço de visão em nuvem) sem alterar o resto do fluxo de cadastro.
"""

from io import BytesIO
from threading import Lock

from PIL import Image, UnidentifiedImageError
from rembg import new_session, remove

from app.core.exceptions import ImagemInvalidaError, ProcessamentoImagemError

# Sem `session`, o `remove()` do rembg recria a sessão do modelo (U²-Net, ~176 MB)
# a cada chamada: ~27 s por foto num notebook, contra ~0,5 s reutilizando a
# sessão. Criada na primeira foto e compartilhada; o lock evita duas threads do
# `run_in_threadpool` criarem a sessão ao mesmo tempo.
_sessao = None
_trava = Lock()


def _obter_sessao():
    global _sessao
    with _trava:
        if _sessao is None:
            _sessao = new_session("u2net")
        return _sessao


def remove_background(imagem_bytes: bytes) -> bytes:
    """Recebe os bytes de uma imagem e retorna PNG com fundo removido.

    Levanta `ImagemInvalidaError` se os bytes não forem uma imagem
    decodificável, ou `ProcessamentoImagemError` se o rembg falhar por
    qualquer outro motivo — nunca deixa a exceção original propagar crua.
    """
    try:
        imagem_original = Image.open(BytesIO(imagem_bytes))
        imagem_original.load()  # Image.open é lazy; só falha ao decodificar de fato
    except UnidentifiedImageError as exc:
        raise ImagemInvalidaError("Imagem inválida ou corrompida.") from exc

    try:
        imagem_processada = remove(imagem_original, session=_obter_sessao())
    except Exception as exc:
        raise ProcessamentoImagemError("Falha ao remover o fundo da imagem.") from exc

    buffer = BytesIO()
    imagem_processada.save(buffer, format="PNG")
    return buffer.getvalue()
