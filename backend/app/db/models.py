import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

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
