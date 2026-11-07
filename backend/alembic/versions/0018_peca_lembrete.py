"""pecas.lembrete_adiado_ate: "lembrar depois" do aviso de peça parada (E13.F1.1)

Data até a qual a peça fica fora de `GET /pecas/paradas`. Nula = sem adiamento;
peças existentes ficam nulas.

Revision ID: 0018
Revises: 0017
Create Date: 2026-11-06

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0018"
down_revision: Union[str, None] = "0017"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("pecas", sa.Column("lembrete_adiado_ate", sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column("pecas", "lembrete_adiado_ate")
