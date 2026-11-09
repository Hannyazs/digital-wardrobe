"""Validação de imagens recebidas do cliente (E1.F1.7).

Compartilhada pelo cadastro de peças e pelo mural de referências: confere o
tamanho e o formato real do arquivo (pelo conteúdo, nunca pelo nome ou pelo
Content-Type enviado) e devolve a extensão segura para gravá-lo.
"""

import io

from PIL import Image, UnidentifiedImageError

from app.core.exceptions import ImagemInvalidaError

TAMANHO_MAX_BYTES = 10 * 1024 * 1024
FORMATOS_ACEITOS = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}


def validar_imagem(imagem_bytes: bytes) -> str:
    """Devolve a extensão segura (jpg, png ou webp) ou levanta `ImagemInvalidaError`."""
    if len(imagem_bytes) > TAMANHO_MAX_BYTES:
        raise ImagemInvalidaError("A imagem passa de 10 MB.")
    try:
        with Image.open(io.BytesIO(imagem_bytes)) as imagem:
            formato = imagem.format
            imagem.verify()
    except (UnidentifiedImageError, OSError, SyntaxError) as exc:
        raise ImagemInvalidaError("O arquivo não é uma imagem válida.") from exc
    extensao = FORMATOS_ACEITOS.get(formato or "")
    if extensao is None:
        raise ImagemInvalidaError("Use uma imagem JPEG, PNG ou WebP.")
    return extensao
