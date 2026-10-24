"""Imagens do mural de referências (E8.F1.1).

Valida que o arquivo é uma imagem aceita e o guarda como veio — sem `rembg`.
As etiquetas das peças visíveis (E8.F4.1) são uma sugestão à parte, da IA
local. Routers não chamam os adapters diretamente (CLAUDE.md, "Camadas do
backend").
"""

import io
import logging

from PIL import Image, UnidentifiedImageError

from app.adapters import ollama_adapter, storage_adapter
from app.core.exceptions import ImagemInvalidaError

logger = logging.getLogger(__name__)

TAMANHO_MAX_BYTES = 10 * 1024 * 1024
FORMATOS_ACEITOS = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}


def salvar_imagem_referencia(imagem_bytes: bytes) -> str:
    """Valida (formato real da imagem, não o nome do arquivo) e salva.
    Devolve a URL pública relativa."""
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
    return storage_adapter.save_image(imagem_bytes, extensao=extensao)


def apagar_imagem_referencia(imagem_url: str) -> None:
    storage_adapter.delete_image(imagem_url)


def etiquetar_imagem_referencia(imagem_bytes: bytes) -> list[str]:
    """Etiquetas das peças visíveis, sugeridas pela IA local (E8.F4.1). Lista
    vazia se a IA falhar: a referência é salva do mesmo jeito."""
    try:
        return ollama_adapter.listar_pecas_visiveis(imagem_bytes)
    except Exception:  # a IA nunca pode impedir o salvamento da referência
        logger.warning("Falha inesperada ao etiquetar a referência", exc_info=True)
        return []
