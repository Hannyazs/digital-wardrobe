"""referencias.look_id: ligar a referência a um look salvo (E8.F3.1)

Uma referência liga-se a no máximo um look; um look pode ter várias
referências. Looks nunca são apagados (excluir = arquivar), mas o
`ON DELETE SET NULL` mantém a coluna segura se isso mudar.

Revision ID: 0016
Revises: 0015
Create Date: 2026-10-23

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0016"
down_revision: Union[str, None] = "0015"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "referencias",
        sa.Column(
            "look_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("looks.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_referencias_look_id", "referencias", ["look_id"])


def downgrade() -> None:
    op.drop_index("ix_referencias_look_id", table_name="referencias")
    op.drop_column("referencias", "look_id")
