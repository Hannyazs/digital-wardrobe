"""pecas: várias estações (`estacoes`) e cores secundárias (multicolorido)

`estacao` (texto) vira `estacoes` (lista); o valor antigo vira lista de um
item. `cores_secundarias` guarda as demais cores de uma peça multicolorida;
a predominante continua em `cor_principal`.

Revision ID: 0012
Revises: 0011
Create Date: 2026-10-23

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ARRAY

revision: str = "0012"
down_revision: Union[str, None] = "0011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "pecas",
        sa.Column("estacoes", ARRAY(sa.String()), nullable=False, server_default=sa.text("'{}'::varchar[]")),
    )
    op.add_column(
        "pecas",
        sa.Column(
            "cores_secundarias", ARRAY(sa.String()), nullable=False, server_default=sa.text("'{}'::varchar[]")
        ),
    )
    op.execute(
        "UPDATE pecas SET estacoes = ARRAY[estacao]::varchar[] "
        "WHERE estacao IS NOT NULL AND estacao <> ''"
    )
    op.drop_column("pecas", "estacao")


def downgrade() -> None:
    op.add_column("pecas", sa.Column("estacao", sa.String(), nullable=True))
    op.execute("UPDATE pecas SET estacao = estacoes[1] WHERE cardinality(estacoes) > 0")
    op.drop_column("pecas", "cores_secundarias")
    op.drop_column("pecas", "estacoes")
