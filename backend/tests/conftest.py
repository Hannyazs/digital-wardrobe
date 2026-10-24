"""Fixtures das rotas do mural (referências e coleções), contra o Postgres local.

Cada teste usa usuários novos e apaga as linhas deles no fim; as imagens vão
para uma pasta temporária. Sem o Postgres do `docker compose` no ar, os testes
que usam estas fixtures são pulados (as demais suítes não dependem de banco).
"""

import uuid

import psycopg2
import pytest
from fastapi import Header
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.adapters import ollama_adapter
from app.core.config import settings
from app.core.security import get_current_user_id
from app.db.session import get_db
from app.main import app


def _psycopg2_dsn() -> str:
    return settings.alembic_database_url.replace("postgresql+psycopg2://", "postgresql://")


@pytest.fixture
def usuarios():
    """Fábrica de ids de usuário; os dados deles são apagados no fim do teste."""
    try:
        conexao = psycopg2.connect(_psycopg2_dsn())
    except psycopg2.OperationalError:
        pytest.skip("Postgres local indisponível")
    criados: list[uuid.UUID] = []

    def novo() -> uuid.UUID:
        usuario = uuid.uuid4()
        criados.append(usuario)
        return usuario

    yield novo

    ids = [str(u) for u in criados]
    with conexao, conexao.cursor() as cursor:
        cursor.execute("DELETE FROM referencias WHERE usuario_id = ANY(%s::uuid[])", (ids,))
        cursor.execute("DELETE FROM colecoes WHERE usuario_id = ANY(%s::uuid[])", (ids,))
        cursor.execute(
            "DELETE FROM looks_pecas WHERE look_id IN (SELECT id FROM looks WHERE usuario_id = ANY(%s::uuid[]))",
            (ids,),
        )
        cursor.execute("DELETE FROM looks WHERE usuario_id = ANY(%s::uuid[])", (ids,))
        cursor.execute("DELETE FROM pecas WHERE usuario_id = ANY(%s::uuid[])", (ids,))
    conexao.close()


@pytest.fixture
def etiquetas_da_ia(monkeypatch):
    """Etiquetas que a IA "devolve" nos testes das rotas (padrão: nenhuma). Os
    testes mudam `etiquetas_da_ia["valor"]` ou levantam exceção em `"erro"`."""
    resposta: dict = {"valor": [], "erro": None, "chamadas": 0}

    def falsa(imagem_bytes: bytes) -> list[str]:
        resposta["chamadas"] += 1
        if resposta["erro"] is not None:
            raise resposta["erro"]
        return list(resposta["valor"])

    monkeypatch.setattr(ollama_adapter, "listar_pecas_visiveis", falsa)
    return resposta


@pytest.fixture
def escolha_da_ia(monkeypatch):
    """A "IA" que compara a referência com as candidatas (E8.F5.2). Padrão: aponta
    sempre a primeira candidata. Os testes trocam `escolha_da_ia["decidir"]`
    (recebe a etiqueta e quantas candidatas vieram; devolve o índice ou `None`)
    e leem `escolha_da_ia["chamadas"]`."""
    estado: dict = {"chamadas": [], "decidir": lambda etiqueta, quantidade: 0}

    def falsa(referencia_bytes, etiqueta, candidatas_bytes, transport=None):
        estado["chamadas"].append((etiqueta, len(candidatas_bytes)))
        return estado["decidir"](etiqueta, len(candidatas_bytes))

    monkeypatch.setattr(ollama_adapter, "escolher_peca_parecida", falsa)
    return estado


@pytest.fixture
def client(tmp_path, monkeypatch, etiquetas_da_ia, escolha_da_ia):
    monkeypatch.setattr(settings, "upload_dir", str(tmp_path))

    async def db_por_requisicao():
        # Uma engine por requisição: o pool global ficaria preso ao loop de outro teste.
        engine = create_async_engine(settings.database_url, poolclass=NullPool)
        try:
            async with async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)() as sessao:
                yield sessao
        finally:
            await engine.dispose()

    def usuario_do_cabecalho(x_usuario: str = Header()) -> uuid.UUID:
        return uuid.UUID(x_usuario)

    app.dependency_overrides[get_db] = db_por_requisicao
    app.dependency_overrides[get_current_user_id] = usuario_do_cabecalho
    with TestClient(app) as cliente:
        yield cliente
    app.dependency_overrides.clear()
