"""cria a tabela referencias (mural de referências, E8.F1.1)

Revision ID: 0014
Revises: 0013
Create Date: 2026-10-23

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0014"
down_revision: Union[str, None] = "0013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "referencias",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("imagem_url", sa.String(), nullable=False),
        sa.Column("nota", sa.Text(), nullable=True),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_referencias_usuario_id", "referencias", ["usuario_id"])


def downgrade() -> None:
    op.drop_index("ix_referencias_usuario_id", table_name="referencias")
    op.drop_table("referencias")
