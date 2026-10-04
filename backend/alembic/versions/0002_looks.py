"""cria tabelas looks e looks_pecas

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-03

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "looks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("nome", sa.String(), nullable=False),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_looks_usuario_id", "looks", ["usuario_id"])

    op.create_table(
        "looks_pecas",
        sa.Column(
            "look_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("looks.id"), primary_key=True
        ),
        sa.Column(
            "peca_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("pecas.id"), primary_key=True
        ),
    )


def downgrade() -> None:
    op.drop_table("looks_pecas")
    op.drop_index("ix_looks_usuario_id", table_name="looks")
    op.drop_table("looks")
