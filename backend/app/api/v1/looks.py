import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_user_id
from app.db.models import Look, LookUso, Peca
from app.db.session import get_db
from app.schemas.look import LookCreate, LookRead, LookUpdate, UsoLookCreate, UsoLookRead

router = APIRouter(prefix="/looks", tags=["looks"])


@router.post("", response_model=LookRead, status_code=201)
async def criar_look(
    dados: LookCreate,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    peca_ids_unicos = set(dados.peca_ids)
    resultado = await db.execute(
        select(Peca).where(Peca.id.in_(peca_ids_unicos), Peca.usuario_id == usuario_id)
    )
    pecas = resultado.scalars().all()
    if len(pecas) != len(peca_ids_unicos):
        # Não distingue "peça não existe" de "peça é de outro usuário" —
        # mesma lógica de não revelar dados de outro usuário já usada em
        # atualizar_peca/excluir_peca.
        raise HTTPException(
            status_code=422, detail="Uma ou mais peças informadas não foram encontradas."
        )

    look = Look(
        usuario_id=usuario_id, nome=dados.nome, ocasioes=dados.ocasioes, pecas=list(pecas)
    )
    db.add(look)
    await db.commit()

    # `refresh()` invalidaria a relação `pecas` já carregada em memória,
    # forçando um lazy-load síncrono fora do greenlet do SQLAlchemy async
    # (MissingGreenlet) na hora de serializar a resposta — por isso a
    # resposta é montada com uma consulta nova, já com eager load.
    resultado = await db.execute(
        select(Look).options(selectinload(Look.pecas)).where(Look.id == look.id)
    )
    return resultado.scalar_one()


# Rotas fixas (`/historico`, `/usos/{id}`) declaradas antes das com `{look_id}`
# para evitar capturas acidentais (E3.F4.1).
@router.get("/historico", response_model=list[UsoLookRead])
async def listar_historico(
    limite: int = Query(100, ge=1, le=500),
    de: date | None = Query(None, description="Início do período (inclusive)."),
    ate: date | None = Query(None, description="Fim do período (inclusive)."),
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    # `de`/`ate` (opcionais) deixam o calendário do app buscar só o mês visível.
    if de is not None and ate is not None and de > ate:
        raise HTTPException(status_code=422, detail="`de` não pode ser depois de `ate`.")

    consulta = (
        select(LookUso)
        .options(selectinload(LookUso.look).selectinload(Look.pecas))
        .where(LookUso.usuario_id == usuario_id)
    )
    if de is not None:
        consulta = consulta.where(LookUso.usado_em >= de)
    if ate is not None:
        consulta = consulta.where(LookUso.usado_em <= ate)
    resultado = await db.execute(
        consulta.order_by(LookUso.usado_em.desc(), LookUso.criado_em.desc()).limit(limite)
    )
    return resultado.scalars().all()


@router.delete("/usos/{uso_id}", status_code=204)
async def excluir_uso(
    uso_id: uuid.UUID,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    resultado = await db.execute(
        select(LookUso).where(LookUso.id == uso_id, LookUso.usuario_id == usuario_id)
    )
    uso = resultado.scalar_one_or_none()
    if uso is None:
        # 404 tanto para inexistente quanto para uso de outro usuário.
        raise HTTPException(status_code=404, detail="Uso não encontrado.")
    await db.delete(uso)
    await db.commit()
    return Response(status_code=204)


@router.post("/{look_id}/usos", response_model=UsoLookRead, status_code=201)
async def registrar_uso(
    look_id: uuid.UUID,
    dados: UsoLookCreate,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    resultado = await db.execute(
        select(Look).where(Look.id == look_id, Look.usuario_id == usuario_id)
    )
    if resultado.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Look não encontrado.")

    uso = LookUso(look_id=look_id, usuario_id=usuario_id, usado_em=dados.usado_em)
    db.add(uso)
    await db.commit()

    # Consulta nova com eager load em vez de `refresh()` (ver `criar_look`).
    resultado = await db.execute(
        select(LookUso)
        .options(selectinload(LookUso.look).selectinload(Look.pecas))
        .where(LookUso.id == uso.id)
    )
    return resultado.scalar_one()


@router.patch("/{look_id}", response_model=LookRead)
async def atualizar_look(
    look_id: uuid.UUID,
    dados: LookUpdate,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    resultado = await db.execute(
        select(Look).where(Look.id == look_id, Look.usuario_id == usuario_id)
    )
    look = resultado.scalar_one_or_none()
    if look is None:
        # 404 tanto para inexistente quanto para look de outro usuário.
        raise HTTPException(status_code=404, detail="Look não encontrado.")

    for campo, valor in dados.model_dump(exclude_unset=True).items():
        setattr(look, campo, valor)
    await db.commit()

    # Consulta nova com eager load em vez de `refresh()` (ver `criar_look`).
    resultado = await db.execute(
        select(Look)
        .options(selectinload(Look.pecas))
        .where(Look.id == look_id)
        .execution_options(populate_existing=True)
    )
    return resultado.scalar_one()


@router.get("", response_model=list[LookRead])
async def listar_looks(
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    resultado = await db.execute(
        select(Look)
        .options(selectinload(Look.pecas))
        .where(Look.usuario_id == usuario_id)
        .order_by(Look.criado_em.desc())
    )
    return resultado.scalars().all()
