"""Atalhos para montar peças de teste do motor de sugestões."""

import uuid

from app.services.sugestoes.tipos import PecaMotor

_contador = 0


def peca(
    categoria: str,
    cor: str | None = None,
    tonalidade: str | None = None,
    estilo: str | None = "Casual",
    estilos: tuple[str, ...] = (),
    estacao: str | None = None,
    ocasioes: tuple[str, ...] = ("Casual",),
    estacoes: tuple[str, ...] = (),
    cores_extras: tuple[str, ...] = (),
) -> PecaMotor:
    """Peça completa por padrão (com estilo e ocasião); ids crescentes e estáveis."""
    global _contador
    _contador += 1
    return PecaMotor(
        id=uuid.UUID(int=_contador),
        categoria=categoria,
        cor=cor,
        tonalidade=tonalidade,
        estilos=estilos or ((estilo,) if estilo else ()),
        estacoes=estacoes or ((estacao,) if estacao else ()),
        cores_extras=cores_extras,
        ocasioes=ocasioes,
    )
