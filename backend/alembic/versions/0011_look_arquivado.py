"""looks: `arquivado` (excluir look = arquivar, E3.F5.1)

Look arquivado some da lista e das ações, mas os usos (`looks_usos`) ficam:
o calendário e a rotação de peças não perdem histórico. Looks existentes
ficam com `false`.

Revision ID: 0011
Revises: 0010
Create Date: 2026-10-22

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0011"
down_revision: Union[str, None] = "0010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "looks",
        sa.Column("arquivado", sa.Boolean(), nullable=False, server_default=sa.false()),
    )


def downgrade() -> None:
    op.drop_column("looks", "arquivado")
