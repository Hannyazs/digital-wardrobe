"""Extração de metadados da peça via Gemini Vision.

TODO: implementar a chamada real ao Gemini (GEMINI_API_KEY em app/core/config.py)
quando o cadastro assistido por IA for implementado. Até lá, retorna uma
sugestão vazia e o usuário preenche os metadados manualmente — ver
CLAUDE.md, convenção "Nada de chamada de IA sem timeout e fallback".
"""

from app.schemas.peca import PecaBase


def extract_metadata(imagem_bytes: bytes) -> PecaBase:
    return PecaBase(categoria="", subcategoria=None, cor_principal=None, estacao=None, ocasiao=None)
