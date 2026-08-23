"""Armazenamento das imagens processadas.

Implementação atual: disco local, servido em /uploads (ver app/main.py).
Isolado atrás desta função para ser trocado por S3/Supabase Storage sem
tocar em services/ ou nos routers — só a implementação abaixo muda.
"""

import uuid
from pathlib import Path

from app.core.config import settings


def save_image(imagem_bytes: bytes, extensao: str = "png") -> str:
    """Salva a imagem processada e retorna a URL pública (relativa)."""
    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)

    nome_arquivo = f"{uuid.uuid4()}.{extensao}"
    caminho = upload_dir / nome_arquivo
    caminho.write_bytes(imagem_bytes)

    return f"/uploads/{nome_arquivo}"
