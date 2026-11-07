"""Peças paradas: sem uso há `DIAS_PARADA` dias ou mais (E13.F1.1).

Uso = a peça estar em um look com registro em `looks_usos`, inclusive looks
arquivados (o histórico continua valendo, E3.F5.1). Peça nunca usada conta a
partir do cadastro (`criado_em`). "Lembrar depois" esconde a peça por
`DIAS_ADIAMENTO` dias (`pecas.lembrete_adiado_ate`).

`hoje` vem sempre do app (fuso do usuário), como `usado_em` em `looks_usos`.
As regras de data são funções puras; `consulta_de_paradas` monta o SQL (um
LEFT JOIN + GROUP BY, sem N+1) usando as mesmas regras.
"""

import uuid
from datetime import date, datetime, timedelta

from sqlalchemy import Date, Select, cast, func, or_, select

from app.db.models import LookUso, Peca, looks_pecas

DIAS_PARADA = 90
DIAS_ADIAMENTO = 30

LIMITE_PADRAO = 5
LIMITE_MAXIMO = 20


def data_de_corte(hoje: date) -> date:
    """Parada se a referência (último uso ou cadastro) for nesta data ou antes."""
    return hoje - timedelta(days=DIAS_PARADA)


def fim_do_adiamento(hoje: date) -> date:
    """`lembrete_adiado_ate` gravado por "Lembrar depois": a peça volta neste dia."""
    return hoje + timedelta(days=DIAS_ADIAMENTO)


def data_de_referencia(ultimo_uso: date | None, criado_em: datetime | date) -> date:
    if ultimo_uso is not None:
        return ultimo_uso
    return criado_em.date() if isinstance(criado_em, datetime) else criado_em


def dias_parada(ultimo_uso: date | None, criado_em: datetime | date, hoje: date) -> int:
    return (hoje - data_de_referencia(ultimo_uso, criado_em)).days


def esta_parada(
    ultimo_uso: date | None,
    criado_em: datetime | date,
    lembrete_adiado_ate: date | None,
    hoje: date,
) -> bool:
    """Mesma regra do `WHERE` de `consulta_de_paradas` (mantenha as duas juntas)."""
    adiada = lembrete_adiado_ate is not None and lembrete_adiado_ate > hoje
    return not adiada and data_de_referencia(ultimo_uso, criado_em) <= data_de_corte(hoje)


def consulta_de_paradas(usuario_id: uuid.UUID, hoje: date, limite: int) -> Select:
    """Linhas `(Peca, ultimo_uso)`, da mais parada para a menos parada (desempate por id).

    `criado_em::date` usa o fuso da sessão do banco (UTC): a peça cadastrada à
    noite no Brasil pode contar um dia a mais. Irrelevante num prazo de 90 dias.
    """
    ultimo_uso = func.max(LookUso.usado_em).label("ultimo_uso")
    referencia = func.coalesce(func.max(LookUso.usado_em), cast(Peca.criado_em, Date))
    return (
        select(Peca, ultimo_uso)
        .outerjoin(looks_pecas, looks_pecas.c.peca_id == Peca.id)
        .outerjoin(LookUso, LookUso.look_id == looks_pecas.c.look_id)
        .where(
            Peca.usuario_id == usuario_id,
            or_(Peca.lembrete_adiado_ate.is_(None), Peca.lembrete_adiado_ate <= hoje),
        )
        .group_by(Peca.id)
        .having(referencia <= data_de_corte(hoje))
        .order_by(referencia, Peca.id)
        .limit(limite)
    )
