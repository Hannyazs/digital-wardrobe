import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, String, Table, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

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
    ocasiao: Mapped[str | None] = mapped_column(String, nullable=True)

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

    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    pecas: Mapped[list[Peca]] = relationship(secondary=looks_pecas)
