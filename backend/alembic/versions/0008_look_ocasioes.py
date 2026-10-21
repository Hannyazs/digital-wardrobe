"""looks: `ocasiao` (texto único) vira `ocasioes` (array de texto)

Um look pode servir a várias ocasiões (ex.: trabalho e faculdade), como já
acontece com as peças (migração 0004). As ocasiões já salvas são preservadas.

Revision ID: 0008
Revises: 0007
Create Date: 2026-10-20

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "looks",
        sa.Column(
            "ocasioes",
            postgresql.ARRAY(sa.String()),
            nullable=False,
            server_default=sa.text("'{}'::varchar[]"),
        ),
    )
    op.execute(
        "UPDATE looks SET ocasioes = ARRAY[ocasiao]::varchar[] "
        "WHERE ocasiao IS NOT NULL AND ocasiao <> ''"
    )
    op.drop_column("looks", "ocasiao")


def downgrade() -> None:
    op.add_column("looks", sa.Column("ocasiao", sa.String(), nullable=True))
    # Só a primeira ocasião sobrevive ao downgrade: a coluna antiga guarda uma.
    op.execute("UPDATE looks SET ocasiao = ocasioes[1] WHERE cardinality(ocasioes) > 0")
    op.drop_column("looks", "ocasioes")
