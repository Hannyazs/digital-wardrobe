"""referencias.etiquetas: peças visíveis na imagem, sugeridas pela IA (E8.F4.1)

Lista de textos curtos ("camiseta branca", "calça jeans"); o usuário edita.
Referências existentes ficam com a lista vazia.

Revision ID: 0017
Revises: 0016
Create Date: 2026-10-23

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ARRAY

revision: str = "0017"
down_revision: Union[str, None] = "0016"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "referencias",
        sa.Column("etiquetas", ARRAY(sa.String()), nullable=False, server_default=sa.text("'{}'::varchar[]")),
    )


def downgrade() -> None:
    op.drop_column("referencias", "etiquetas")
