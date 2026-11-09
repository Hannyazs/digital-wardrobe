"""Imagens do mural de referências (E8.F1.1).

Valida que o arquivo é uma imagem aceita e o guarda como veio — sem `rembg`.
As etiquetas das peças visíveis (E8.F4.1) são uma sugestão à parte, da IA
local. Routers não chamam os adapters diretamente (CLAUDE.md, "Camadas do
backend").
"""

import logging

from app.adapters import ollama_adapter, storage_adapter
from app.services.validacao_imagem import TAMANHO_MAX_BYTES, validar_imagem

logger = logging.getLogger(__name__)


def salvar_imagem_referencia(imagem_bytes: bytes) -> str:
    """Valida (formato real da imagem, não o nome do arquivo) e salva.
    Devolve a URL pública relativa."""
    extensao = validar_imagem(imagem_bytes)
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
