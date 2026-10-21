import uuid

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_user_id
from app.db.models import CombinacaoEvitada, Peca, PecaEvitada, Preferencia
from app.db.session import get_db
from app.schemas.peca import PecaRead
from app.schemas.preferencia import (
    CombinacaoEvitadaCreate,
    CombinacaoEvitadaRead,
    EvitadasRead,
    PecaEvitadaCreate,
    PreferenciaRead,
    PreferenciaUpdate,
    preferencia_padrao,
)

router = APIRouter(prefix="/preferencias", tags=["preferencias"])


async def _ler(db: AsyncSession, usuario_id: uuid.UUID) -> PreferenciaRead:
    resultado = await db.execute(select(Preferencia).where(Preferencia.usuario_id == usuario_id))
    preferencia = resultado.scalar_one_or_none()
    # Sem linha: devolve os padrões, sem gravar nada.
    return PreferenciaRead.model_validate(preferencia) if preferencia else preferencia_padrao()


@router.get("", response_model=PreferenciaRead)
async def obter_preferencias(
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    return await _ler(db, usuario_id)


@router.patch("", response_model=PreferenciaRead)
async def atualizar_preferencias(
    dados: PreferenciaUpdate,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    valores = dados.model_dump(exclude_unset=True)
    if not valores:
        # Corpo `{}`: nada a gravar (e não cria a linha só por isso).
        return await _ler(db, usuario_id)

    # Upsert atômico: duas primeiras chamadas simultâneas não geram erro de
    # chave duplicada em `usuario_id`.
    comando = (
        pg_insert(Preferencia)
        .values(usuario_id=usuario_id, **valores)
        .on_conflict_do_update(
            index_elements=[Preferencia.usuario_id],
            # `onupdate` do model não vale para ON CONFLICT: atualizar na mão.
            set_={**valores, "atualizado_em": func.now()},
        )
        .returning(Preferencia)
    )
    resultado = await db.execute(comando)
    # Serializa antes do `commit()`: depois dele a instância expira e ler
    # atributos dispararia lazy-load fora do greenlet (MissingGreenlet).
    resposta = PreferenciaRead.model_validate(resultado.scalar_one())
    await db.commit()
    return resposta


# --- E4.F4.1: peças e combinações evitadas -----------------------------------
# Restrição para o Épico 6 ("nunca me sugira"). Só peças do próprio usuário:
# peça inexistente ou de outro usuário é 404, sem distinguir os dois casos
# (mesma regra de `criar_look`/`atualizar_peca`).


async def _pecas_do_usuario(
    db: AsyncSession, usuario_id: uuid.UUID, peca_ids: set[uuid.UUID]
) -> dict[uuid.UUID, Peca]:
    resultado = await db.execute(
        select(Peca).where(Peca.id.in_(peca_ids), Peca.usuario_id == usuario_id)
    )
    pecas = {peca.id: peca for peca in resultado.scalars().all()}
    if len(pecas) != len(peca_ids):
        raise HTTPException(status_code=404, detail="Peça não encontrada.")
    return pecas


@router.get("/evitadas", response_model=EvitadasRead)
async def listar_evitadas(
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    pecas = await db.execute(
        select(PecaEvitada)
        .options(selectinload(PecaEvitada.peca))
        .where(PecaEvitada.usuario_id == usuario_id)
        .order_by(PecaEvitada.criado_em.desc())
    )
    combinacoes = await db.execute(
        select(CombinacaoEvitada)
        .options(selectinload(CombinacaoEvitada.peca_a), selectinload(CombinacaoEvitada.peca_b))
        .where(CombinacaoEvitada.usuario_id == usuario_id)
        .order_by(CombinacaoEvitada.criado_em.desc())
    )
    return EvitadasRead(
        pecas=[PecaRead.model_validate(item.peca) for item in pecas.scalars().all()],
        combinacoes=[
            CombinacaoEvitadaRead(
                id=par.id,
                pecas=[PecaRead.model_validate(par.peca_a), PecaRead.model_validate(par.peca_b)],
            )
            for par in combinacoes.scalars().all()
        ],
    )


@router.post("/pecas-evitadas", response_model=PecaRead, status_code=201)
async def evitar_peca(
    dados: PecaEvitadaCreate,
    response: Response,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    pecas = await _pecas_do_usuario(db, usuario_id, {dados.peca_id})
    # Idempotente e seguro contra corrida: 201 se marcou agora, 200 se já estava.
    resultado = await db.execute(
        pg_insert(PecaEvitada)
        .values(usuario_id=usuario_id, peca_id=dados.peca_id)
        .on_conflict_do_nothing(index_elements=["usuario_id", "peca_id"])
        .returning(PecaEvitada.peca_id)
    )
    if resultado.scalar_one_or_none() is None:
        response.status_code = 200
    # Serializa antes do commit (depois dele a instância expira).
    resposta = PecaRead.model_validate(pecas[dados.peca_id])
    await db.commit()
    return resposta


@router.delete("/pecas-evitadas/{peca_id}", status_code=204)
async def parar_de_evitar_peca(
    peca_id: uuid.UUID,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    resultado = await db.execute(
        delete(PecaEvitada).where(
            PecaEvitada.usuario_id == usuario_id, PecaEvitada.peca_id == peca_id
        )
    )
    if resultado.rowcount == 0:
        raise HTTPException(status_code=404, detail="Peça evitada não encontrada.")
    await db.commit()
    return Response(status_code=204)


@router.post("/combinacoes-evitadas", response_model=CombinacaoEvitadaRead, status_code=201)
async def evitar_combinacao(
    dados: CombinacaoEvitadaCreate,
    response: Response,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    pecas = await _pecas_do_usuario(db, usuario_id, {dados.peca_a_id, dados.peca_b_id})
    # Par sem ordem: grava sempre ordenado (`uuid.UUID` compara como o banco,
    # o que bate com a CheckConstraint `peca_a_id < peca_b_id`).
    peca_a_id, peca_b_id = sorted((dados.peca_a_id, dados.peca_b_id))
    resultado = await db.execute(
        pg_insert(CombinacaoEvitada)
        .values(usuario_id=usuario_id, peca_a_id=peca_a_id, peca_b_id=peca_b_id)
        .on_conflict_do_nothing(index_elements=["usuario_id", "peca_a_id", "peca_b_id"])
        .returning(CombinacaoEvitada.id)
    )
    par_id = resultado.scalar_one_or_none()
    if par_id is None:
        # Já existia (em qualquer ordem): devolve o mesmo registro.
        response.status_code = 200
        par_id = await db.scalar(
            select(CombinacaoEvitada.id).where(
                CombinacaoEvitada.usuario_id == usuario_id,
                CombinacaoEvitada.peca_a_id == peca_a_id,
                CombinacaoEvitada.peca_b_id == peca_b_id,
            )
        )
    resposta = CombinacaoEvitadaRead(
        id=par_id,
        pecas=[PecaRead.model_validate(pecas[peca_a_id]), PecaRead.model_validate(pecas[peca_b_id])],
    )
    await db.commit()
    return resposta


@router.delete("/combinacoes-evitadas/{combinacao_id}", status_code=204)
async def parar_de_evitar_combinacao(
    combinacao_id: uuid.UUID,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    resultado = await db.execute(
        delete(CombinacaoEvitada).where(
            CombinacaoEvitada.usuario_id == usuario_id, CombinacaoEvitada.id == combinacao_id
        )
    )
    if resultado.rowcount == 0:
        raise HTTPException(status_code=404, detail="Combinação evitada não encontrada.")
    await db.commit()
    return Response(status_code=204)

