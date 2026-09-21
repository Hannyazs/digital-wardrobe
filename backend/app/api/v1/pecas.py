import logging
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ImagemInvalidaError, ProcessamentoImagemError
from app.core.security import get_current_user_id
from app.db.models import Peca
from app.db.session import get_db
from app.schemas.peca import (
    ImagemOriginalResponse,
    ImagemProcessadaResponse,
    PecaCreate,
    PecaRead,
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
    resultado = await db.execute(select(Peca).where(Peca.usuario_id == usuario_id))
    return resultado.scalars().all()
