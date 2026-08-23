"""cria extensao pgvector e tabela pecas

Revision ID: 0001
Revises:
Create Date: 2026-08-16

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Habilita a extensão usada para embeddings de estilo (recomendação /
    # inspiração por imagem — ver CLAUDE.md, "Papel do pgvector"). A coluna
    # vector em si entra em uma migração futura, quando a feature for implementada.
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "pecas",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("imagem_url", sa.String(), nullable=False),
        sa.Column("categoria", sa.String(), nullable=False),
        sa.Column("subcategoria", sa.String(), nullable=True),
        sa.Column("cor_principal", sa.String(), nullable=True),
        sa.Column("estacao", sa.String(), nullable=True),
        sa.Column("ocasiao", sa.String(), nullable=True),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_pecas_usuario_id", "pecas", ["usuario_id"])


def downgrade() -> None:
    op.drop_index("ix_pecas_usuario_id", table_name="pecas")
    op.drop_table("pecas")
    op.execute("DROP EXTENSION IF EXISTS vector")
