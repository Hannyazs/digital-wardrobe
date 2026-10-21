"""cria tabela looks_usos (histórico de uso de looks)

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-16

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "looks_usos",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("look_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("looks.id"), nullable=False),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usado_em", sa.Date(), nullable=False),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_looks_usos_usuario_id", "looks_usos", ["usuario_id"])


def downgrade() -> None:
    op.drop_index("ix_looks_usos_usuario_id", table_name="looks_usos")
    op.drop_table("looks_usos")
