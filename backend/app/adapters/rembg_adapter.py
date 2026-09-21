"""Remoção de fundo das fotos de peças, via rembg.

Isolado em adapter porque é a etapa mais provável de trocar (ex: por um
serviço de visão em nuvem) sem alterar o resto do fluxo de cadastro.
"""

from io import BytesIO

from PIL import Image, UnidentifiedImageError
from rembg import remove

from app.core.exceptions import ImagemInvalidaError, ProcessamentoImagemError


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
        imagem_processada = remove(imagem_original)
    except Exception as exc:
        raise ProcessamentoImagemError("Falha ao remover o fundo da imagem.") from exc

    buffer = BytesIO()
    imagem_processada.save(buffer, format="PNG")
    return buffer.getvalue()
