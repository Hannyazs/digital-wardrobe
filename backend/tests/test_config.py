"""Configuração de produção (E9.F3.2): a API não sobe com padrões de desenvolvimento.

Sem banco nem rede; o `.env` local é ignorado (`_env_file=None`).
"""

import pytest
from pydantic import ValidationError

from app.core.config import Settings

BASE = {
    "database_url": "postgresql+asyncpg://u:s@h/db",
    "alembic_database_url": "postgresql+psycopg2://u:s@h/db",
}
PRODUCAO_OK = {
    **BASE,
    "ambiente": "producao",
    "supabase_url": "https://projeto.supabase.co",
    "supabase_jwt_secret": "",
    "cors_origins": "https://app.exemplo.com.br",
}


def _settings(**valores) -> Settings:
    return Settings(_env_file=None, **valores)


def test_desenvolvimento_continua_aceitando_os_padroes_locais():
    s = _settings(**BASE, supabase_jwt_secret="changeme", cors_origins="http://localhost:8080")
    assert not s.em_producao
    assert s.cors_origins_list == ["http://localhost:8080"]


def test_producao_bem_configurada_sobe():
    s = _settings(**PRODUCAO_OK)
    assert s.em_producao
    assert s.cors_origins_list == ["https://app.exemplo.com.br"]


@pytest.mark.parametrize(
    "mudanca,trecho",
    [
        ({"supabase_jwt_secret": "changeme"}, "SUPABASE_JWT_SECRET precisa ficar vazio"),
        ({"supabase_url": ""}, "SUPABASE_URL"),
        ({"supabase_url": "http://projeto.supabase.co"}, "SUPABASE_URL"),
        ({"cors_origins": "*"}, "não pode ser '*'"),
        ({"cors_origins": ""}, "precisa listar"),
        ({"cors_origins": "http://app.exemplo.com.br"}, "só aceita origens https"),
        ({"cors_origins": "https://app.exemplo.com.br,https://localhost:8080"}, "origem local"),
    ],
)
def test_producao_recusa_configuracao_de_desenvolvimento(mudanca, trecho):
    with pytest.raises(ValidationError) as erro:
        _settings(**(PRODUCAO_OK | mudanca))
    assert trecho in str(erro.value)


def test_producao_lista_todos_os_problemas_de_uma_vez():
    with pytest.raises(ValidationError) as erro:
        _settings(**BASE, ambiente="producao", supabase_jwt_secret="x", cors_origins="*")
    mensagem = str(erro.value)
    assert "SUPABASE_URL" in mensagem and "SUPABASE_JWT_SECRET" in mensagem and "'*'" in mensagem


def test_ambiente_desconhecido_e_recusado():
    with pytest.raises(ValidationError):
        _settings(**BASE, ambiente="homologacao")


def _preflight(origem: str):
    from fastapi.testclient import TestClient

    from app.main import app

    return TestClient(app).options(
        "/api/v1/pecas",
        headers={
            "Origin": origem,
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization",
        },
    )


def test_preflight_de_origem_permitida_e_liberado():
    from app.core.config import settings

    origem = settings.cors_origins_list[0]
    resposta = _preflight(origem)
    assert resposta.status_code == 200
    assert resposta.headers["access-control-allow-origin"] == origem


def test_preflight_de_origem_nao_permitida_e_bloqueado():
    resposta = _preflight("https://site-qualquer.exemplo")
    assert resposta.status_code == 400
    assert "access-control-allow-origin" not in resposta.headers


def test_cors_nao_libera_credenciais_de_navegador():
    from app.main import app

    cors = next(m for m in app.user_middleware if m.cls.__name__ == "CORSMiddleware")
    assert cors.kwargs["allow_credentials"] is False
    assert "*" not in cors.kwargs["allow_origins"]
