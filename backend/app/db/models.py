import uuid
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    ForeignKey,
    SmallInteger,
    String,
    Table,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import expression

from app.db.session import Base

# NOTA: a coluna de embedding de estilo (pgvector) entra via migração própria
# quando a recomendação por IA / inspiração por imagem forem implementadas
# (MVP #4 e #5) — ver CLAUDE.md, seção "Papel do pgvector".


class Peca(Base):
    __tablename__ = "pecas"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    usuario_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)

    imagem_url: Mapped[str] = mapped_column(String, nullable=False)

    categoria: Mapped[str] = mapped_column(String, nullable=False)
    subcategoria: Mapped[str | None] = mapped_column(String, nullable=True)
    cor_principal: Mapped[str | None] = mapped_column(String, nullable=True)
    estacao: Mapped[str | None] = mapped_column(String, nullable=True)
    # Cor e tonalidade são informações distintas (ex.: azul-marinho / escura) —
    # a tonalidade ajuda a combinar peças na recomendação de looks.
    tonalidade_cor: Mapped[str | None] = mapped_column(String, nullable=True)
    estilo: Mapped[str | None] = mapped_column(String, nullable=True)
    modelagem: Mapped[str | None] = mapped_column(String, nullable=True)
    # Uma peça pode servir a várias ocasiões; "Outros" guarda o texto digitado.
    ocasioes: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default=text("'{}'::varchar[]")
    )

    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


# Associação N:N entre looks e peças (E3.F1.1) — sem colunas além das FKs:
# a ordem de montagem do look não é um requisito do MVP ainda.
looks_pecas = Table(
    "looks_pecas",
    Base.metadata,
    Column("look_id", UUID(as_uuid=True), ForeignKey("looks.id"), primary_key=True),
    Column("peca_id", UUID(as_uuid=True), ForeignKey("pecas.id"), primary_key=True),
)


class Look(Base):
    __tablename__ = "looks"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    usuario_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)

    nome: Mapped[str] = mapped_column(String, nullable=False)

    # E3.F2.1 — server_default faz looks anteriores à migração 0003 virarem `false`.
    favorito: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=expression.false()
    )

    # E3.F3.1 — texto livre, sem enum no banco (mesmo critério de `Peca`: a
    # lista fixa de ocasiões é só UX no app). Um look pode servir a várias
    # ocasiões (migração 0008: antes era um texto único).
    ocasioes: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default=text("'{}'::varchar[]")
    )

    # E3.F5.1 — "excluir" um look arquiva: some da lista e das ações, mas os
    # usos (`looks_usos`) continuam no histórico e na rotação de peças.
    arquivado: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=expression.false()
    )

    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    pecas: Mapped[list[Peca]] = relationship(secondary=looks_pecas)


class LookUso(Base):
    """Um registro por uso de um look (E3.F4.1) — não um contador no look: o
    histórico precisa do *quando*, e as sugestões (Épicos 5 e 6) leem recência e
    frequência daqui."""

    __tablename__ = "looks_usos"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    look_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("looks.id"), nullable=False)
    usuario_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)

    # Data informada pelo app, no fuso do usuário (o servidor não assume "hoje").
    usado_em: Mapped[date] = mapped_column(Date, nullable=False)

    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    look: Mapped[Look] = relationship()


class Preferencia(Base):
    """Preferências de estilo do usuário (E4.F1.1): uma linha por usuário.
    Peças e combinações evitadas ficam em tabelas próprias (E4.F4.1)."""

    __tablename__ = "preferencias"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    usuario_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, unique=True)

    # Texto livre (sem enum): as listas fixas de opções são só UX no app.
    # Listas: atribuir sempre uma lista nova — o SQLAlchemy não detecta
    # mutação in-place (`append`) em ARRAY/JSONB.
    estilos: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default=text("'{}'::varchar[]")
    )
    sobreposicoes: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default=text("'{}'::varchar[]")
    )
    # Lista de pares: [{"cor_a": "Azul", "cor_b": "Branco"}, ...]
    combinacoes_cores: Mapped[list[dict]] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    # 1 (combinações seguras) a 5 (ousadas); 3 = equilibrado.
    criatividade: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="3")
    # E6.F1.1 — última ocasião escolhida no look do dia; NULL = "Casual".
    ocasiao_look_do_dia: Mapped[str | None] = mapped_column(String, nullable=True)

    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    atualizado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# E4.F4.1 — peças e pares de peças que o usuário evita. Para as sugestões (Épicos 5 e 6) são
# RESTRIÇÃO ("nunca me sugira"), não peso. FKs com ON DELETE CASCADE: a peça
# é apagada fisicamente (`excluir_peca`, E1.F3.1) e estas linhas vão junto,
# pelo banco — sem `relationship` do lado de `Peca`.


class PecaEvitada(Base):
    __tablename__ = "pecas_evitadas"

    usuario_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    peca_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("pecas.id", ondelete="CASCADE"), primary_key=True, index=True
    )
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    peca: Mapped[Peca] = relationship()


class CombinacaoEvitada(Base):
    """Par sem ordem, guardado sempre com `peca_a_id < peca_b_id`."""

    __tablename__ = "combinacoes_evitadas"
    __table_args__ = (
        CheckConstraint("peca_a_id < peca_b_id", name="ck_combinacoes_evitadas_ordem"),
        UniqueConstraint("usuario_id", "peca_a_id", "peca_b_id", name="uq_combinacoes_evitadas_par"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    usuario_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    peca_a_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("pecas.id", ondelete="CASCADE"), nullable=False, index=True
    )
    peca_b_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("pecas.id", ondelete="CASCADE"), nullable=False, index=True
    )
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    peca_a: Mapped[Peca] = relationship(foreign_keys=[peca_a_id])
    peca_b: Mapped[Peca] = relationship(foreign_keys=[peca_b_id])
