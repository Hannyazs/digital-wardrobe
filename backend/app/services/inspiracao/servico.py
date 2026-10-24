"""Liga a sugestão de look aos adaptadores reais (storage e Ollama).

Routers não chamam os adapters diretamente (CLAUDE.md, "Camadas do backend"):
passam por aqui. A lógica fica em `sugestao.py`, que é pura e testável.
"""

import uuid
from collections.abc import Collection, Mapping, Sequence

from app.adapters import ollama_adapter, storage_adapter
from app.core.config import settings
from app.services.inspiracao.candidatos import PecaCandidata
from app.services.inspiracao.sugestao import ResultadoSugestao, sugerir_look


class ImagemDaReferenciaIndisponivelError(Exception):
    """A foto da referência não está mais no armazenamento."""


def sugerir_para_referencia(
    imagem_url: str,
    etiquetas: Sequence[str],
    pecas: Sequence[PecaCandidata],
    imagens_das_pecas: Mapping[uuid.UUID, str],
    evitadas: Collection[uuid.UUID],
    looks_salvos: Mapping[uuid.UUID, Collection[uuid.UUID]],
) -> ResultadoSugestao:
    try:
        imagem_referencia = storage_adapter.read_image(imagem_url)
    except OSError as erro:
        raise ImagemDaReferenciaIndisponivelError(imagem_url) from erro

    return sugerir_look(
        etiquetas=etiquetas,
        pecas=pecas,
        evitadas=evitadas,
        looks_salvos=looks_salvos,
        imagem_referencia=imagem_referencia,
        ler_imagem=lambda peca_id: storage_adapter.read_image(imagens_das_pecas[peca_id]),
        # Acessado na hora da chamada (não importado como nome) para os testes trocarem.
        escolher=lambda ref, etiqueta, fotos: ollama_adapter.escolher_peca_parecida(ref, etiqueta, fotos),
        tempo_max_s=settings.sugestao_tempo_max_s,
    )
