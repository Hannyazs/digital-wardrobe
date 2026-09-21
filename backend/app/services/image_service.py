"""Orquestra o pré-processamento de uma foto de peça: remove o fundo,
guarda a imagem tratada e pede à IA uma sugestão de metadados.

Routers não chamam os adapters diretamente — sempre passam por aqui.
Ver CLAUDE.md, seção "Camadas do backend".
"""

from app.adapters import gemini_adapter, rembg_adapter, storage_adapter
from app.schemas.peca import ImagemProcessadaResponse


def processar_imagem_peca(imagem_bytes: bytes) -> ImagemProcessadaResponse:
    imagem_sem_fundo = rembg_adapter.remove_background(imagem_bytes)
    imagem_url = storage_adapter.save_image(imagem_sem_fundo)
    sugestao = gemini_adapter.extract_metadata(imagem_sem_fundo)

    return ImagemProcessadaResponse(imagem_url=imagem_url, sugestao=sugestao)


def salvar_imagem_original(imagem_bytes: bytes, extensao: str) -> str:
    """Salva a foto sem remoção de fundo (E1.F1.4) — usado quando o
    processamento falhou e o usuário optou por continuar sem ele."""
    return storage_adapter.save_image(imagem_bytes, extensao=extensao)
