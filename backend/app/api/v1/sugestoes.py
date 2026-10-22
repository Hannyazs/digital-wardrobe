import uuid
from dataclasses import dataclass
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import get_current_user_id
from app.db.models import (
    CombinacaoEvitada,
    Look,
    LookUso,
    Peca,
    PecaEvitada,
    Preferencia,
    looks_pecas,
)
from app.db.session import get_db
from app.schemas.peca import PecaRead
from app.schemas.preferencia import PreferenciaRead, preferencia_padrao
from app.schemas.sugestao import (
    ConflitoRead,
    LookDoDiaPedido,
    LookDoDiaRead,
    LookSugeridoRead,
    SugestaoPedido,
    SugestoesRead,
)
from app.services.sugestoes.servico import (
    OCASIAO_PADRAO_LOOK_DO_DIA,
    LookSugerido,
    conjuntos_por_look,
    mensagem_conflito,
    sugerir,
    sugerir_look_do_dia,
)
from app.services.sugestoes.tipos import (
    ContextoRotatividade,
    Filtros,
    PecaMotor,
    PreferenciasMotor,
    Restricoes,
)

router = APIRouter(prefix="/sugestoes", tags=["sugestoes"])


def _para_motor(peca: Peca) -> PecaMotor:
    return PecaMotor(
        id=peca.id,
        categoria=peca.categoria,
        cor=peca.cor_principal,
        tonalidade=peca.tonalidade_cor,
        estilo=peca.estilo,
        estacao=peca.estacao,
        ocasioes=tuple(peca.ocasioes or ()),
    )


def _preferencias_motor(preferencia: PreferenciaRead) -> PreferenciasMotor:
    return PreferenciasMotor(
        estilos=frozenset(preferencia.estilos),
        sobreposicoes=frozenset(preferencia.sobreposicoes),
        pares_favoritos=frozenset(
            frozenset({par.cor_a, par.cor_b}) for par in preferencia.combinacoes_cores
        ),
        criatividade=preferencia.criatividade,
    )


@dataclass
class _DadosDoUsuario:
    pecas: list[Peca]
    preferencia: PreferenciaRead
    restricoes: Restricoes
    usos: dict[uuid.UUID, int]
    ultimos_usos: dict[uuid.UUID, date]


async def _carregar(
    db: AsyncSession, usuario_id: uuid.UUID, usos_antes_de: date | None = None
) -> _DadosDoUsuario:
    """Tudo filtrado por usuario_id: o motor só enxerga dados do próprio usuário.

    `usos_antes_de` limita os usos às datas anteriores (look do dia estável no dia).
    """
    pecas = (await db.execute(select(Peca).where(Peca.usuario_id == usuario_id))).scalars().all()

    linha_pref = (
        await db.execute(select(Preferencia).where(Preferencia.usuario_id == usuario_id))
    ).scalar_one_or_none()
    preferencia = (
        PreferenciaRead.model_validate(linha_pref) if linha_pref else preferencia_padrao()
    )

    evitadas = (
        await db.execute(select(PecaEvitada.peca_id).where(PecaEvitada.usuario_id == usuario_id))
    ).scalars().all()
    pares_evitados = (
        await db.execute(
            select(CombinacaoEvitada.peca_a_id, CombinacaoEvitada.peca_b_id).where(
                CombinacaoEvitada.usuario_id == usuario_id
            )
        )
    ).all()

    # Usos de cada peça = registros de uso dos looks que a contêm.
    consulta_usos = (
        select(looks_pecas.c.peca_id, func.count(LookUso.id), func.max(LookUso.usado_em))
        .join(LookUso, LookUso.look_id == looks_pecas.c.look_id)
        .where(LookUso.usuario_id == usuario_id)
        .group_by(looks_pecas.c.peca_id)
    )
    if usos_antes_de is not None:
        consulta_usos = consulta_usos.where(LookUso.usado_em < usos_antes_de)
    linhas_usos = (await db.execute(consulta_usos)).all()

    return _DadosDoUsuario(
        pecas=list(pecas),
        preferencia=preferencia,
        restricoes=Restricoes(
            pecas_evitadas=frozenset(evitadas),
            pares_evitados=frozenset(frozenset(par) for par in pares_evitados),
        ),
        usos={peca_id: total for peca_id, total, _ in linhas_usos},
        ultimos_usos={peca_id: ultimo for peca_id, _, ultimo in linhas_usos},
    )


async def _looks_salvos(db: AsyncSession, usuario_id: uuid.UUID) -> list[frozenset[uuid.UUID]]:
    """Conjunto de peças de cada look salvo do usuário (E5.F1.3). Looks
    arquivados (E3.F5.1) não contam: o usuário os excluiu."""
    linhas = (
        await db.execute(
            select(looks_pecas.c.look_id, looks_pecas.c.peca_id)
            .join(Look, Look.id == looks_pecas.c.look_id)
            .where(Look.usuario_id == usuario_id, Look.arquivado.is_(False))
        )
    ).all()
    return conjuntos_por_look(linhas)


def _look_read(look: LookSugerido, pecas_por_id: dict[uuid.UUID, Peca]) -> LookSugeridoRead:
    return LookSugeridoRead(
        pecas=[PecaRead.model_validate(pecas_por_id[p.id]) for p in look.candidato.pecas],
        explicacoes=look.explicacoes,
        avisos=look.avisos,
    )


@router.post("", response_model=SugestoesRead)
async def sugerir_looks(
    pedido: SugestaoPedido,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    dados = await _carregar(db, usuario_id)
    pecas_por_id = {p.id: p for p in dados.pecas}
    if pedido.peca_base_id is not None and pedido.peca_base_id not in pecas_por_id:
        # 404 tanto para inexistente quanto para peça de outro usuário.
        raise HTTPException(status_code=404, detail="Peça não encontrada.")

    resultado = sugerir(
        pecas=[_para_motor(p) for p in dados.pecas],
        filtros=Filtros(
            ocasiao=pedido.ocasiao, estilo=pedido.estilo, estacao=pedido.estacao, cor=pedido.cor
        ),
        prefs=_preferencias_motor(dados.preferencia),
        restricoes=dados.restricoes,
        usos=dados.usos,
        pagina=pedido.pagina,
        # Looks já salvos contam como descartados: a aba Sugestões não os
        # repete (E5.F1.3). O look do dia não faz isso (decisão do usuário).
        descartados=[frozenset(ids) for ids in pedido.descartados]
        + await _looks_salvos(db, usuario_id),
        peca_base_id=pedido.peca_base_id,
        limite=settings.sugestoes_max_candidatos,
    )

    return SugestoesRead(
        looks=[_look_read(look, pecas_por_id) for look in resultado.looks],
        pagina=resultado.pagina,
        tem_mais=resultado.tem_mais,
        motivo=resultado.motivo,
        conflitos=[
            ConflitoRead(
                filtro=c.filtro,
                valor_filtro=c.valor_filtro,
                valor_peca=c.valor_peca,
                mensagem=mensagem_conflito(c),
            )
            for c in resultado.conflitos
        ],
    )


@router.post("/look-do-dia", response_model=LookDoDiaRead)
async def look_do_dia(
    pedido: LookDoDiaPedido,
    usuario_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    # Só usos anteriores à data: registrar "Usei hoje" não troca o look do dia.
    dados = await _carregar(db, usuario_id, usos_antes_de=pedido.data)
    ocasiao = (
        pedido.ocasiao or dados.preferencia.ocasiao_look_do_dia or OCASIAO_PADRAO_LOOK_DO_DIA
    )

    resultado = sugerir_look_do_dia(
        pecas=[_para_motor(p) for p in dados.pecas],
        ocasiao=ocasiao,
        prefs=_preferencias_motor(dados.preferencia),
        restricoes=dados.restricoes,
        usos=dados.usos,
        contexto=ContextoRotatividade(data=pedido.data, ultimos_usos=dados.ultimos_usos),
        descartados=[frozenset(ids) for ids in pedido.descartados],
        limite=settings.sugestoes_max_candidatos,
    )

    pecas_por_id = {p.id: p for p in dados.pecas}
    return LookDoDiaRead(
        look=_look_read(resultado.looks[0], pecas_por_id) if resultado.looks else None,
        ocasiao=ocasiao,
        tem_mais=resultado.tem_mais,
        motivo=resultado.motivo,
    )
