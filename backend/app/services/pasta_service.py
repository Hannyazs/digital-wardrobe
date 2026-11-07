"""Consultas das pastas de looks (E3.F6.1). Espelha `colecao_service.py`."""

import uuid

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Look, PastaLook


async def nome_em_uso(
    db: AsyncSession, usuario_id: uuid.UUID, nome: str, ignorar_id: uuid.UUID | None = None
) -> bool:
    """Já existe outra pasta do usuário com este nome (sem diferenciar caixa)?"""
    consulta = select(PastaLook.id).where(
        PastaLook.usuario_id == usuario_id, func.lower(PastaLook.nome) == nome.lower()
    )
    if ignorar_id is not None:
        consulta = consulta.where(PastaLook.id != ignorar_id)
    return (await db.scalar(consulta)) is not None


async def listar_com_quantidade(db: AsyncSession, usuario_id: uuid.UUID) -> list[dict]:
    """Pastas em ordem alfabética, com a contagem de looks não arquivados numa consulta só."""
    resultado = await db.execute(
        select(PastaLook, func.count(Look.id))
        .outerjoin(Look, and_(Look.pasta_id == PastaLook.id, Look.arquivado.is_(False)))
        .where(PastaLook.usuario_id == usuario_id)
        .group_by(PastaLook.id)
        .order_by(func.lower(PastaLook.nome), PastaLook.id)
    )
    return [
        {"id": p.id, "nome": p.nome, "quantidade": total, "criado_em": p.criado_em}
        for p, total in resultado.all()
    ]


async def quantidade_de(db: AsyncSession, pasta_id: uuid.UUID) -> int:
    return await db.scalar(
        select(func.count()).select_from(Look).where(Look.pasta_id == pasta_id, Look.arquivado.is_(False))
    )


async def pasta_do_usuario(db: AsyncSession, pasta_id: uuid.UUID, usuario_id: uuid.UUID) -> PastaLook | None:
    pasta = await db.get(PastaLook, pasta_id)
    return pasta if pasta is not None and pasta.usuario_id == usuario_id else None
