import logging
import uuid

from fastapi import APIRouter, Depends, Form, HTTPException, Query, UploadFile
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ImagemInvalidaError
from app.core.security import get_current_user_id
from app.db.models import Colecao, Look, Peca, PecaEvitada, Referencia
from app.db.session import get_db
from app.schemas.peca import PecaRead
from app.schemas.referencia import NOTA_MAX, ReferenciaRead, ReferenciaUpdate, limpar_nota
from app.schemas.sugestao_de_look import ItemDaSugestaoRead, LookSalvoRead, SugestaoDeLookRead
from app.services.inspiracao.candidatos import PecaCandidata
from app.services.inspiracao.servico import (
    ImagemDaReferenciaIndisponivelError,
    sugerir_para_referencia,
)
from app.services.inspiracao.sugestao import TIPO_LOOK_SALVO
from app.services.referencia_service import (
    apagar_imagem_referencia,
    etiquetar_imagem_referencia,
    salvar_imagem_referencia,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/referencias", tags=["referencias"])


async def _do_usuario(db: AsyncSession, referencia_id: uuid.UUID, usuario_id: uuid.UUID) -> Referencia:
    referencia = await db.get(Referencia, referencia_id)
    if referencia is None or referencia.usuario_id != usuario_id:
        # 404 nos dois casos: nunca revela a referência de outro usuário.
        raise HTTPException(status_code=404, detail="Referência não encontrada.")
    return referencia


async def _colecao_do_usuario(db: AsyncSession, colecao_id: uuid.UUID, usuario_id: uuid.UUID) -> None:
    colecao = await db.get(Colecao, colecao_id)
    if colecao is None or colecao.usuario_id != usuario_id:
        raise HTTPException(status_code=404, detail="Coleção não encontrada.")


async def _look_do_usuario(db: AsyncSession, look_id: uuid.UUID, usuario_id: uuid.UUID) -> None:
    """Look do usuário e não arquivado; senão 404 (o mesmo para inexistente,
    de outro usuário ou arquivado)."""
    look = await db.get(Look, look_id)
    if look is None or look.usuario_id != usuario_id or look.arquivado:
        raise HTTPException(status_code=404, detail="Look não encontrado.")


@router.post("", response_model=ReferenciaRead, status_code=201)
async def criar_referencia(
    arquivo: UploadFile,
    nota: str | None = Form(None, max_length=NOTA_MAX),
    colecao_id: uuid.UUID | None = Form(None),
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if colecao_id is not None:
        await _colecao_do_usuario(db, colecao_id, usuario_id)
    imagem_bytes = await arquivo.read()
    try:
        imagem_url = await run_in_threadpool(salvar_imagem_referencia, imagem_bytes)
    except ImagemInvalidaError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    # Sem espera extra além do tempo limite da IA; se ela falhar, a lista vem vazia.
    etiquetas = await run_in_threadpool(etiquetar_imagem_referencia, imagem_bytes)

    referencia = Referencia(
        usuario_id=usuario_id,
        imagem_url=imagem_url,
        nota=limpar_nota(nota),
        colecao_id=colecao_id,
        etiquetas=etiquetas,
    )
    db.add(referencia)
    await db.commit()
    await db.refresh(referencia)
    return referencia


@router.get("", response_model=list[ReferenciaRead])
async def listar_referencias(
    colecao_id: uuid.UUID | None = None,
    sem_colecao: bool = Query(False),
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Todas as referências do usuário; `?colecao_id=` ou `?sem_colecao=true` filtram."""
    if colecao_id is not None and sem_colecao:
        raise HTTPException(status_code=422, detail="Use colecao_id ou sem_colecao, não os dois.")
    consulta = select(Referencia).where(Referencia.usuario_id == usuario_id)
    if colecao_id is not None:
        consulta = consulta.where(Referencia.colecao_id == colecao_id)
    elif sem_colecao:
        consulta = consulta.where(Referencia.colecao_id.is_(None))
    resultado = await db.execute(consulta.order_by(Referencia.criado_em.desc(), Referencia.id))
    return resultado.scalars().all()


@router.patch("/{referencia_id}", response_model=ReferenciaRead)
async def atualizar_referencia(
    referencia_id: uuid.UUID,
    dados: ReferenciaUpdate,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    referencia = await _do_usuario(db, referencia_id, usuario_id)
    if "nota" in dados.model_fields_set:
        referencia.nota = dados.nota
    if "colecao_id" in dados.model_fields_set:
        if dados.colecao_id is not None:
            await _colecao_do_usuario(db, dados.colecao_id, usuario_id)
        referencia.colecao_id = dados.colecao_id
    if "etiquetas" in dados.model_fields_set:
        referencia.etiquetas = dados.etiquetas
    if "look_id" in dados.model_fields_set:
        if dados.look_id is not None:
            await _look_do_usuario(db, dados.look_id, usuario_id)
        referencia.look_id = dados.look_id
    await db.commit()
    await db.refresh(referencia)
    return referencia


@router.delete("/{referencia_id}", status_code=204)
async def excluir_referencia(
    referencia_id: uuid.UUID,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    referencia = await _do_usuario(db, referencia_id, usuario_id)
    imagem_url = referencia.imagem_url
    await db.delete(referencia)
    await db.commit()
    try:
        await run_in_threadpool(apagar_imagem_referencia, imagem_url)
    except OSError:
        # O registro já foi removido; arquivo órfão não deve virar erro para quem excluiu.
        logger.warning("Não foi possível apagar o arquivo %s", imagem_url, exc_info=True)


@router.post("/{referencia_id}/sugestao-de-look", response_model=SugestaoDeLookRead)
async def sugerir_look_da_referencia(
    referencia_id: uuid.UUID,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Sugere um look com as peças do usuário a partir das etiquetas da referência
    (E8.F5.2). O Gemma compara a foto da referência com as candidatas de cada
    etiqueta; não grava nada. Só enxerga dados do `usuario_id` do JWT."""
    referencia = await _do_usuario(db, referencia_id, usuario_id)
    if not referencia.etiquetas:
        raise HTTPException(status_code=422, detail="Adicione as etiquetas das peças primeiro.")

    pecas = (await db.execute(select(Peca).where(Peca.usuario_id == usuario_id))).scalars().all()
    evitadas = (
        await db.execute(select(PecaEvitada.peca_id).where(PecaEvitada.usuario_id == usuario_id))
    ).scalars().all()
    looks = (
        await db.execute(
            select(Look)
            .options(selectinload(Look.pecas))
            .where(Look.usuario_id == usuario_id, Look.arquivado.is_(False))
        )
    ).scalars().all()

    try:
        resultado = await run_in_threadpool(
            sugerir_para_referencia,
            referencia.imagem_url,
            list(referencia.etiquetas),
            [
                PecaCandidata(
                    id=p.id,
                    categoria=p.categoria,
                    subcategoria=p.subcategoria,
                    cor=p.cor_principal,
                    cores_extras=tuple(p.cores_secundarias or ()),
                )
                for p in pecas
            ],
            {p.id: p.imagem_url for p in pecas},
            frozenset(evitadas),
            {look.id: [p.id for p in look.pecas] for look in looks},
        )
    except ImagemDaReferenciaIndisponivelError as exc:
        raise HTTPException(status_code=404, detail="A imagem da referência não está mais disponível.") from exc

    por_id = {p.id: p for p in pecas}
    look_salvo = None
    if resultado.tipo == TIPO_LOOK_SALVO:
        look = next(look for look in looks if look.id == resultado.look_id)
        look_salvo = LookSalvoRead(
            id=look.id, nome=look.nome, pecas=[PecaRead.model_validate(p) for p in look.pecas]
        )
    return SugestaoDeLookRead(
        tipo=resultado.tipo,
        look=look_salvo,
        pecas=[PecaRead.model_validate(por_id[i]) for i in resultado.pecas_ids],
        itens=[
            ItemDaSugestaoRead(
                etiqueta=i.etiqueta,
                peca=PecaRead.model_validate(por_id[i.peca_id]) if i.peca_id else None,
                situacao=i.situacao,
                cor_diferente=i.cor_diferente,
            )
            for i in resultado.itens
        ],
        lacunas=list(resultado.lacunas),
    )
