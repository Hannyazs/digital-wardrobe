import logging
import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, Response, UploadFile
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ImagemInvalidaError, ProcessamentoImagemError
from app.core.security import get_current_user_id
from app.db.models import Look, Peca, looks_pecas
from app.db.session import get_db
from app.schemas.peca import (
    ImagemOriginalResponse,
    ImagemProcessadaResponse,
    PecaCreate,
    PecaParadaRead,
    PecaRead,
    PecaUpdate,
)
from app.services import pecas_paradas
from app.services.image_service import processar_imagem_peca, salvar_imagem_original
from app.services.validacao_imagem import TAMANHO_MAX_BYTES
from app.services.peca_consulta import (
    LIMITE_MAXIMO,
    condicoes_de_filtro,
    consulta_de_pecas,
    contagem_de_pecas,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/pecas", tags=["pecas"])


@router.post("/processar-imagem", response_model=ImagemProcessadaResponse)
async def processar_imagem(
    arquivo: UploadFile,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
):
    """Recebe a foto, remove o fundo e devolve uma sugestão de metadados
    para o usuário revisar antes de confirmar o cadastro (POST /pecas).
    Exige login (E1.F1.7); o `usuario_id` só barra anônimos por enquanto."""
    # Lê no máximo o limite + 1 byte: um envio gigante é recusado sem ir à memória.
    imagem_bytes = await arquivo.read(TAMANHO_MAX_BYTES + 1)
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
async def upload_imagem_original(
    arquivo: UploadFile,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
):
    """Salva a foto original sem processamento — usado quando
    /processar-imagem falhou e o usuário optou por continuar sem
    remoção de fundo (E1.F1.4). Exige login, valida o tipo real e ignora
    o nome enviado (E1.F1.7)."""
    imagem_bytes = await arquivo.read(TAMANHO_MAX_BYTES + 1)
    try:
        imagem_url = await run_in_threadpool(salvar_imagem_original, imagem_bytes)
    except ImagemInvalidaError as exc:
        logger.warning("Imagem inválida recebida em /upload-original: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc)) from exc
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
    response: Response,
    limite: int | None = Query(default=None, ge=1, le=LIMITE_MAXIMO),
    deslocamento: int = Query(default=0, ge=0),
    categoria: list[str] = Query(default=[]),
    outras: bool = False,
    cor: list[str] = Query(default=[]),
    estacao: list[str] = Query(default=[]),
    ocasiao: list[str] = Query(default=[]),
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Lista as peças do usuário (E11.F1.1), da mais nova para a mais antiga
    (desempate por id). Sem parâmetros devolve todas, como antes.

    - `limite`/`deslocamento`: paginação por offset (máximo de `LIMITE_MAXIMO`
      por página; acima disso a requisição é rejeitada com 422).
    - `categoria` (repetível), `outras` (categorias fora da lista fixa), `cor`,
      `estacao` e `ocasiao` (repetíveis): OU dentro de um critério, E entre
      critérios. Regras em `services/peca_consulta.py`.
    - `X-Total-Count`: total que satisfaz os filtros, ignorando a paginação.

    Limitação do offset: se uma peça for criada ou excluída entre duas páginas,
    um item pode se repetir ou ser pulado; o app deduplica por `id` e atualiza
    ao puxar para atualizar.
    """
    condicoes = condicoes_de_filtro(
        categorias=categoria, outras=outras, cores=cor, estacoes=estacao, ocasioes=ocasiao
    )
    consulta = consulta_de_pecas(usuario_id, condicoes)
    if limite is not None:
        consulta = consulta.limit(limite).offset(deslocamento)
    elif deslocamento:
        consulta = consulta.offset(deslocamento)

    total = await db.scalar(contagem_de_pecas(usuario_id, condicoes))
    response.headers["X-Total-Count"] = str(total or 0)
    resultado = await db.execute(consulta)
    return resultado.scalars().all()


@router.get("/paradas", response_model=list[PecaParadaRead])
async def listar_pecas_paradas(
    hoje: date | None = Query(default=None, description="Data do app (AAAA-MM-DD), no fuso do usuário."),
    limite: int = Query(default=pecas_paradas.LIMITE_PADRAO, ge=1, le=pecas_paradas.LIMITE_MAXIMO),
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Peças sem uso há 90 dias ou mais (E13.F1.1), da mais parada para a menos
    parada. Uso em look arquivado conta; peça nunca usada conta do cadastro;
    peça com "lembrar depois" em vigor fica de fora. Regras em
    `services/pecas_paradas.py`."""
    hoje = hoje or date.today()
    resultado = await db.execute(pecas_paradas.consulta_de_paradas(usuario_id, hoje, limite))
    return [
        PecaParadaRead(
            peca=PecaRead.model_validate(peca),
            ultimo_uso=ultimo_uso,
            dias_parada=pecas_paradas.dias_parada(ultimo_uso, peca.criado_em, hoje),
        )
        for peca, ultimo_uso in resultado.all()
    ]


@router.post("/{peca_id}/adiar-lembrete", status_code=204)
async def adiar_lembrete(
    peca_id: uuid.UUID,
    hoje: date | None = Query(default=None, description="Data do app (AAAA-MM-DD), no fuso do usuário."),
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """"Lembrar depois" (E13.F1.1): a peça sai de GET /pecas/paradas por 30 dias."""
    peca = await db.get(Peca, peca_id)
    if peca is None or peca.usuario_id != usuario_id:
        raise HTTPException(status_code=404, detail="Peça não encontrada.")
    peca.lembrete_adiado_ate = pecas_paradas.fim_do_adiamento(hoje or date.today())
    await db.commit()
    return Response(status_code=204)


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

    # Só looks ativos contam (E3.F5.1): vínculos com looks arquivados saem
    # junto com a peça, sem perguntar.
    total_looks = await db.scalar(
        select(func.count())
        .select_from(looks_pecas)
        .join(Look, Look.id == looks_pecas.c.look_id)
        .where(looks_pecas.c.peca_id == peca_id, Look.arquivado.is_(False))
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

    await db.execute(delete(looks_pecas).where(looks_pecas.c.peca_id == peca_id))
    await db.delete(peca)
    await db.commit()
