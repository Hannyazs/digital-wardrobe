"""cria pecas_evitadas e combinacoes_evitadas (E4.F4.1)

Peças e pares de peças que o usuário não quer ver nas sugestões. FKs para
`pecas` com ON DELETE CASCADE — exceção ao padrão do projeto: `excluir_peca`
(E1.F3.1) apaga a peça fisicamente, e estas linhas são dado derivado dela.

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-20

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _fk_peca(nome: str) -> sa.Column:
    return sa.Column(
        nome,
        postgresql.UUID(as_uuid=True),
        sa.ForeignKey("pecas.id", ondelete="CASCADE"),
        nullable=False,
    )


def upgrade() -> None:
    op.create_table(
        "pecas_evitadas",
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        _fk_peca("peca_id"),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now()),
        # A PK começa por `usuario_id`: serve também de índice por usuário.
        sa.PrimaryKeyConstraint("usuario_id", "peca_id", name="pk_pecas_evitadas"),
    )
    # Índice na FK: o CASCADE ao excluir uma peça procura por `peca_id`.
    op.create_index("ix_pecas_evitadas_peca_id", "pecas_evitadas", ["peca_id"])

    op.create_table(
        "combinacoes_evitadas",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        _fk_peca("peca_a_id"),
        _fk_peca("peca_b_id"),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now()),
        # Par sem ordem guardado sempre ordenado: (A, B) e (B, A) são o mesmo.
        sa.CheckConstraint("peca_a_id < peca_b_id", name="ck_combinacoes_evitadas_ordem"),
        sa.UniqueConstraint(
            "usuario_id", "peca_a_id", "peca_b_id", name="uq_combinacoes_evitadas_par"
        ),
    )
    op.create_index("ix_combinacoes_evitadas_usuario_id", "combinacoes_evitadas", ["usuario_id"])
    op.create_index("ix_combinacoes_evitadas_peca_a_id", "combinacoes_evitadas", ["peca_a_id"])
    op.create_index("ix_combinacoes_evitadas_peca_b_id", "combinacoes_evitadas", ["peca_b_id"])


def downgrade() -> None:
    op.drop_table("combinacoes_evitadas")
    op.drop_table("pecas_evitadas")
