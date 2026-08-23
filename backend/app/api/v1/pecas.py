import uuid

from fastapi import APIRouter, Depends, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.db.models import Peca
from app.db.session import get_db
from app.schemas.peca import ImagemProcessadaResponse, PecaCreate, PecaRead
from app.services.image_service import processar_imagem_peca

router = APIRouter(prefix="/pecas", tags=["pecas"])


@router.post("/processar-imagem", response_model=ImagemProcessadaResponse)
async def processar_imagem(arquivo: UploadFile):
    """Recebe a foto, remove o fundo e devolve uma sugestão de metadados
    para o usuário revisar antes de confirmar o cadastro (POST /pecas)."""
    imagem_bytes = await arquivo.read()
    return processar_imagem_peca(imagem_bytes)


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
