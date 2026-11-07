import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.db.models import PastaLook
from app.db.session import get_db
from app.schemas.pasta import PastaRead, PastaWrite
from app.services import pasta_service

router = APIRouter(prefix="/pastas", tags=["pastas"])

_NOME_REPETIDO = "Já existe uma pasta com esse nome."


async def _do_usuario(db: AsyncSession, pasta_id: uuid.UUID, usuario_id: uuid.UUID) -> PastaLook:
    pasta = await pasta_service.pasta_do_usuario(db, pasta_id, usuario_id)
    if pasta is None:
        # 404 nos dois casos: nunca revela a pasta de outro usuário.
        raise HTTPException(status_code=404, detail="Pasta não encontrada.")
    return pasta


async def _gravar(db: AsyncSession) -> None:
    try:
        await db.commit()
    except IntegrityError as exc:
        # Duas requisições ao mesmo tempo com o mesmo nome: o índice único decide.
        await db.rollback()
        raise HTTPException(status_code=409, detail=_NOME_REPETIDO) from exc


@router.post("", response_model=PastaRead, status_code=201)
async def criar_pasta(
    dados: PastaWrite,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if await pasta_service.nome_em_uso(db, usuario_id, dados.nome):
        raise HTTPException(status_code=409, detail=_NOME_REPETIDO)
    pasta = PastaLook(usuario_id=usuario_id, nome=dados.nome)
    db.add(pasta)
    await _gravar(db)
    await db.refresh(pasta)
    return PastaRead(id=pasta.id, nome=pasta.nome, quantidade=0, criado_em=pasta.criado_em)


@router.get("", response_model=list[PastaRead])
async def listar_pastas(
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Pastas em ordem alfabética, com a quantidade de looks não arquivados."""
    return await pasta_service.listar_com_quantidade(db, usuario_id)


@router.patch("/{pasta_id}", response_model=PastaRead)
async def renomear_pasta(
    pasta_id: uuid.UUID,
    dados: PastaWrite,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    pasta = await _do_usuario(db, pasta_id, usuario_id)
    if await pasta_service.nome_em_uso(db, usuario_id, dados.nome, ignorar_id=pasta.id):
        raise HTTPException(status_code=409, detail=_NOME_REPETIDO)
    pasta.nome = dados.nome
    await _gravar(db)
    await db.refresh(pasta)
    quantidade = await pasta_service.quantidade_de(db, pasta.id)
    return PastaRead(id=pasta.id, nome=pasta.nome, quantidade=quantidade, criado_em=pasta.criado_em)


@router.delete("/{pasta_id}", status_code=204)
async def excluir_pasta(
    pasta_id: uuid.UUID,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Exclui só a pasta: os looks ficam, sem pasta (`ON DELETE SET NULL`)."""
    pasta = await _do_usuario(db, pasta_id, usuario_id)
    await db.delete(pasta)
    await db.commit()
