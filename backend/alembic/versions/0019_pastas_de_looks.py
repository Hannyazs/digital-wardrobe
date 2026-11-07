"""cria pastas_looks e looks.pasta_id (E3.F6.1)

Um look fica em no máximo uma pasta. Excluir a pasta não apaga os looks:
`pasta_id` volta a nulo ("Sem pasta"). O nome é único por usuário sem
diferenciar maiúsculas (mesmo desenho de `colecoes`, 0015).

Revision ID: 0019
Revises: 0018
Create Date: 2026-11-07

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0019"
down_revision: Union[str, None] = "0018"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "pastas_looks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("nome", sa.String(), nullable=False),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_pastas_looks_usuario_id", "pastas_looks", ["usuario_id"])
    op.create_index(
        "uq_pastas_looks_usuario_nome", "pastas_looks", ["usuario_id", sa.text("lower(nome)")], unique=True
    )

    op.add_column(
        "looks",
        sa.Column(
            "pasta_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("pastas_looks.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_looks_pasta_id", "looks", ["pasta_id"])


def downgrade() -> None:
    op.drop_index("ix_looks_pasta_id", table_name="looks")
    op.drop_column("looks", "pasta_id")
    op.drop_index("uq_pastas_looks_usuario_nome", table_name="pastas_looks")
    op.drop_index("ix_pastas_looks_usuario_id", table_name="pastas_looks")
    op.drop_table("pastas_looks")
