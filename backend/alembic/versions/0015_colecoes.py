"""cria colecoes e referencias.colecao_id (E8.F2.1)

Uma referência fica em no máximo uma coleção. Excluir a coleção não apaga as
referências: `colecao_id` volta a nulo ("Sem coleção"). O nome é único por
usuário sem diferenciar maiúsculas.

Revision ID: 0015
Revises: 0014
Create Date: 2026-10-23

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0015"
down_revision: Union[str, None] = "0014"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "colecoes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("nome", sa.String(), nullable=False),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_colecoes_usuario_id", "colecoes", ["usuario_id"])
    op.create_index("uq_colecoes_usuario_nome", "colecoes", ["usuario_id", sa.text("lower(nome)")], unique=True)

    op.add_column(
        "referencias",
        sa.Column(
            "colecao_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("colecoes.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_referencias_colecao_id", "referencias", ["colecao_id"])


def downgrade() -> None:
    op.drop_index("ix_referencias_colecao_id", table_name="referencias")
    op.drop_column("referencias", "colecao_id")
    op.drop_index("uq_colecoes_usuario_nome", table_name="colecoes")
    op.drop_index("ix_colecoes_usuario_id", table_name="colecoes")
    op.drop_table("colecoes")
