"""Remoção de fundo das fotos de peças, via rembg.

Isolado em adapter porque é a etapa mais provável de trocar (ex: por um
serviço de visão em nuvem) sem alterar o resto do fluxo de cadastro.
"""

from io import BytesIO

from PIL import Image
from rembg import remove


def remove_background(imagem_bytes: bytes) -> bytes:
    """Recebe os bytes de uma imagem e retorna PNG com fundo removido."""
    imagem_original = Image.open(BytesIO(imagem_bytes))
    imagem_processada = remove(imagem_original)

    buffer = BytesIO()
    imagem_processada.save(buffer, format="PNG")
    return buffer.getvalue()
