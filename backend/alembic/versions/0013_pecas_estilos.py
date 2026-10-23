"""pecas: vários estilos (`estilos`)

`estilo` (texto) vira `estilos` (lista); o valor antigo vira lista de um item.
Uma peça de festa pode ser também casual, por exemplo.

Revision ID: 0013
Revises: 0012
Create Date: 2026-10-23

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ARRAY

revision: str = "0013"
down_revision: Union[str, None] = "0012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "pecas",
        sa.Column("estilos", ARRAY(sa.String()), nullable=False, server_default=sa.text("'{}'::varchar[]")),
    )
    op.execute(
        "UPDATE pecas SET estilos = ARRAY[estilo]::varchar[] "
        "WHERE estilo IS NOT NULL AND estilo <> ''"
    )
    op.drop_column("pecas", "estilo")


def downgrade() -> None:
    op.add_column("pecas", sa.Column("estilo", sa.String(), nullable=True))
    op.execute("UPDATE pecas SET estilo = estilos[1] WHERE cardinality(estilos) > 0")
    op.drop_column("pecas", "estilos")
