import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_user_id
from app.db.models import Look, Peca
from app.db.session import get_db
from app.schemas.look import LookCreate, LookRead

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

    look = Look(usuario_id=usuario_id, nome=dados.nome, pecas=list(pecas))
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
