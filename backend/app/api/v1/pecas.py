import logging
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ImagemInvalidaError, ProcessamentoImagemError
from app.core.security import get_current_user_id
from app.db.models import Peca, looks_pecas
from app.db.session import get_db
from app.schemas.peca import (
    ImagemOriginalResponse,
    ImagemProcessadaResponse,
    PecaCreate,
    PecaRead,
    PecaUpdate,
)
from app.services.image_service import processar_imagem_peca, salvar_imagem_original

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/pecas", tags=["pecas"])


@router.post("/processar-imagem", response_model=ImagemProcessadaResponse)
async def processar_imagem(arquivo: UploadFile):
    """Recebe a foto, remove o fundo e devolve uma sugestão de metadados
    para o usuário revisar antes de confirmar o cadastro (POST /pecas)."""
    imagem_bytes = await arquivo.read()
    try:
        # Despachada em threadpool: rembg é CPU-bound e síncrono, chamá-la
        # direto aqui bloquearia o event loop inteiro durante o processamento.
        return await run_in_threadpool(processar_imagem_peca, imagem_bytes)
    except ImagemInvalidaError as exc:
        logger.warning("Imagem inválida recebida em /processar-imagem: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except ProcessamentoImagemError as exc:
        logger.error("Falha ao processar imagem", exc_info=exc)
        raise HTTPException(
            status_code=500, detail="Falha ao processar a imagem. Tente novamente."
        ) from exc


@router.post("/upload-original", response_model=ImagemOriginalResponse)
async def upload_imagem_original(arquivo: UploadFile):
    """Salva a foto original sem processamento — usado quando
    /processar-imagem falhou e o usuário optou por continuar sem
    remoção de fundo (E1.F1.4)."""
    imagem_bytes = await arquivo.read()
    extensao = Path(arquivo.filename or "").suffix.lstrip(".") or "jpg"
    imagem_url = await run_in_threadpool(salvar_imagem_original, imagem_bytes, extensao)
    return ImagemOriginalResponse(imagem_url=imagem_url)


@router.post("", response_model=PecaRead, status_code=201)
async def criar_peca(
    dados: PecaCreate,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    peca = Peca(usuario_id=usuario_id, **dados.model_dump())
    db.add(peca)
    await db.commit()
    await db.refresh(peca)
    return peca


@router.get("", response_model=list[PecaRead])
async def listar_pecas(
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    resultado = await db.execute(
        select(Peca).where(Peca.usuario_id == usuario_id).order_by(Peca.criado_em.desc())
    )
    return resultado.scalars().all()


@router.put("/{peca_id}", response_model=PecaRead)
async def atualizar_peca(
    peca_id: uuid.UUID,
    dados: PecaUpdate,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Edita os metadados de uma peça (E1.F3.1) — nunca a imagem_url."""
    peca = await db.get(Peca, peca_id)
    if peca is None or peca.usuario_id != usuario_id:
        # 404 em ambos os casos — nunca revela que a peça existe e é de outro usuário.
        raise HTTPException(status_code=404, detail="Peça não encontrada.")

    for campo, valor in dados.model_dump().items():
        setattr(peca, campo, valor)

    await db.commit()
    await db.refresh(peca)
    return peca


@router.delete("/{peca_id}", status_code=204)
async def excluir_peca(
    peca_id: uuid.UUID,
    remover_dos_looks: bool = False,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Exclui uma peça (E1.F3.1) — física e definitiva, sem soft-delete.

    Se a peça está em looks salvos, responde 409 com a quantidade de looks e
    nada é apagado. Com `remover_dos_looks=true` (o app só envia depois do
    usuário confirmar), a peça sai desses looks — que continuam existindo —
    e então é excluída.
    """
    peca = await db.get(Peca, peca_id)
    if peca is None or peca.usuario_id != usuario_id:
        raise HTTPException(status_code=404, detail="Peça não encontrada.")

    total_looks = await db.scalar(
        select(func.count()).select_from(looks_pecas).where(looks_pecas.c.peca_id == peca_id)
    )
    if total_looks and not remover_dos_looks:
        raise HTTPException(
            status_code=409,
            detail={
                "codigo": "peca_em_looks",
                "looks": total_looks,
                "mensagem": f"Esta peça está em {total_looks} look(s).",
            },
        )

    if total_looks:
        await db.execute(delete(looks_pecas).where(looks_pecas.c.peca_id == peca_id))
    await db.delete(peca)
    await db.commit()
