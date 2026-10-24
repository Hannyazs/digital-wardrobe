import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.db.models import Colecao
from app.db.session import get_db
from app.schemas.colecao import ColecaoRead, ColecaoWrite
from app.services import colecao_service

router = APIRouter(prefix="/colecoes", tags=["colecoes"])

_NOME_REPETIDO = "Já existe uma coleção com esse nome."


async def _do_usuario(db: AsyncSession, colecao_id: uuid.UUID, usuario_id: uuid.UUID) -> Colecao:
    colecao = await db.get(Colecao, colecao_id)
    if colecao is None or colecao.usuario_id != usuario_id:
        # 404 nos dois casos: nunca revela a coleção de outro usuário.
        raise HTTPException(status_code=404, detail="Coleção não encontrada.")
    return colecao


async def _gravar(db: AsyncSession) -> None:
    try:
        await db.commit()
    except IntegrityError as exc:
        # Duas requisições ao mesmo tempo com o mesmo nome: o índice único decide.
        await db.rollback()
        raise HTTPException(status_code=409, detail=_NOME_REPETIDO) from exc


@router.post("", response_model=ColecaoRead, status_code=201)
async def criar_colecao(
    dados: ColecaoWrite,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if await colecao_service.nome_em_uso(db, usuario_id, dados.nome):
        raise HTTPException(status_code=409, detail=_NOME_REPETIDO)
    colecao = Colecao(usuario_id=usuario_id, nome=dados.nome)
    db.add(colecao)
    await _gravar(db)
    await db.refresh(colecao)
    return ColecaoRead(id=colecao.id, nome=colecao.nome, quantidade=0, criado_em=colecao.criado_em)


@router.get("", response_model=list[ColecaoRead])
async def listar_colecoes(
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    return await colecao_service.listar_com_quantidade(db, usuario_id)


@router.patch("/{colecao_id}", response_model=ColecaoRead)
async def renomear_colecao(
    colecao_id: uuid.UUID,
    dados: ColecaoWrite,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    colecao = await _do_usuario(db, colecao_id, usuario_id)
    if await colecao_service.nome_em_uso(db, usuario_id, dados.nome, ignorar_id=colecao.id):
        raise HTTPException(status_code=409, detail=_NOME_REPETIDO)
    colecao.nome = dados.nome
    await _gravar(db)
    await db.refresh(colecao)
    quantidade = await colecao_service.quantidade_de(db, colecao.id)
    return ColecaoRead(id=colecao.id, nome=colecao.nome, quantidade=quantidade, criado_em=colecao.criado_em)


@router.delete("/{colecao_id}", status_code=204)
async def excluir_colecao(
    colecao_id: uuid.UUID,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Exclui só a coleção: as referências ficam, sem coleção (`ON DELETE SET NULL`)."""
    colecao = await _do_usuario(db, colecao_id, usuario_id)
    await db.delete(colecao)
    await db.commit()
