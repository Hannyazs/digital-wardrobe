"""preferencias: `ocasiao_look_do_dia` (última ocasião escolhida no look do dia)

Coluna opcional: sem valor, o look do dia usa "Casual" (E6.F1.1). Linhas já
existentes ficam com NULL, sem conversão de dados.

Revision ID: 0010
Revises: 0009
Create Date: 2026-10-21

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0010"
down_revision: Union[str, None] = "0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("preferencias", sa.Column("ocasiao_look_do_dia", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("preferencias", "ocasiao_look_do_dia")
