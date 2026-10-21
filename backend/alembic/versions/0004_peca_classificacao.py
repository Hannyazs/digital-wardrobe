"""peças: tonalidade_cor, estilo, modelagem e ocasioes (múltiplas)

`ocasiao` (texto único) vira `ocasioes` (array de texto): uma peça pode servir
a várias situações. Os valores antigos são copiados antes de a coluna antiga
ser removida, então nenhuma peça já cadastrada perde a ocasião.

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-14

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("pecas", sa.Column("tonalidade_cor", sa.String(), nullable=True))
    op.add_column("pecas", sa.Column("estilo", sa.String(), nullable=True))
    op.add_column("pecas", sa.Column("modelagem", sa.String(), nullable=True))
    op.add_column(
        "pecas",
        sa.Column(
            "ocasioes",
            postgresql.ARRAY(sa.String()),
            nullable=False,
            server_default=sa.text("'{}'::varchar[]"),
        ),
    )
    op.execute(
        "UPDATE pecas SET ocasioes = ARRAY[ocasiao]::varchar[] "
        "WHERE ocasiao IS NOT NULL AND ocasiao <> ''"
    )
    op.drop_column("pecas", "ocasiao")


def downgrade() -> None:
    op.add_column("pecas", sa.Column("ocasiao", sa.String(), nullable=True))
    # Só a primeira ocasião sobrevive ao downgrade: a coluna antiga guarda uma.
    op.execute("UPDATE pecas SET ocasiao = ocasioes[1] WHERE cardinality(ocasioes) > 0")
    op.drop_column("pecas", "ocasioes")
    op.drop_column("pecas", "modelagem")
    op.drop_column("pecas", "estilo")
    op.drop_column("pecas", "tonalidade_cor")
