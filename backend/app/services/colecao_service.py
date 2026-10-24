"""Consultas das coleções do mural (E8.F2.1)."""

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Colecao, Referencia


async def nome_em_uso(
    db: AsyncSession, usuario_id: uuid.UUID, nome: str, ignorar_id: uuid.UUID | None = None
) -> bool:
    """Já existe outra coleção do usuário com este nome (sem diferenciar caixa)?"""
    consulta = select(Colecao.id).where(
        Colecao.usuario_id == usuario_id, func.lower(Colecao.nome) == nome.lower()
    )
    if ignorar_id is not None:
        consulta = consulta.where(Colecao.id != ignorar_id)
    return (await db.scalar(consulta)) is not None


async def listar_com_quantidade(db: AsyncSession, usuario_id: uuid.UUID) -> list[dict]:
    """Coleções em ordem alfabética, com a contagem de referências numa consulta só."""
    resultado = await db.execute(
        select(Colecao, func.count(Referencia.id))
        .outerjoin(Referencia, Referencia.colecao_id == Colecao.id)
        .where(Colecao.usuario_id == usuario_id)
        .group_by(Colecao.id)
        .order_by(func.lower(Colecao.nome), Colecao.id)
    )
    return [
        {"id": c.id, "nome": c.nome, "quantidade": total, "criado_em": c.criado_em}
        for c, total in resultado.all()
    ]


async def quantidade_de(db: AsyncSession, colecao_id: uuid.UUID) -> int:
    return await db.scalar(select(func.count()).select_from(Referencia).where(Referencia.colecao_id == colecao_id))
