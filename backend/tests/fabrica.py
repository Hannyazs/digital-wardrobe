"""Atalhos para montar peças de teste do motor de sugestões."""

import uuid

from app.services.sugestoes.tipos import PecaMotor

_contador = 0


def peca(
    categoria: str,
    cor: str | None = None,
    tonalidade: str | None = None,
    estilo: str | None = "Casual",
    estacao: str | None = None,
    ocasioes: tuple[str, ...] = ("Casual",),
) -> PecaMotor:
    """Peça completa por padrão (com estilo e ocasião); ids crescentes e estáveis."""
    global _contador
    _contador += 1
    return PecaMotor(
        id=uuid.UUID(int=_contador),
        categoria=categoria,
        cor=cor,
        tonalidade=tonalidade,
        estilo=estilo,
        estacao=estacao,
        ocasioes=ocasioes,
    )
