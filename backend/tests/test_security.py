"""Validação do JWT (E9.F1.1): tokens do Supabase (ES256 + JWKS) e de desenvolvimento (HS256).

As chaves são geradas aqui; o JWKS "do projeto" é servido por um cliente com a
busca de rede trocada, então nenhum teste depende de internet nem de banco.
"""

import base64
import hashlib
import hmac
import json
import time
import uuid

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import Depends, FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.core import security
from app.core.config import settings

URL_PROJETO = "https://projeto-teste.supabase.co"
EMISSOR = f"{URL_PROJETO}/auth/v1"
SEGREDO_DEV = "segredo-de-teste-com-mais-de-32-bytes"


def _nova_chave(kid: str) -> tuple[ec.EllipticCurvePrivateKey, dict]:
    privada = ec.generate_private_key(ec.SECP256R1())
    jwk = json.loads(jwt.algorithms.ECAlgorithm.to_jwk(privada.public_key()))
    jwk.update({"kid": kid, "alg": "ES256", "use": "sig"})
    return privada, jwk


class JwksFalso:
    """Faz o papel do endpoint JWKS do projeto; conta quantas vezes foi consultado."""

    def __init__(self) -> None:
        self.chaves: list[dict] = []
        self.buscas = 0
        self.erro: Exception | None = None

    def buscar(self) -> dict:
        self.buscas += 1
        if self.erro is not None:
            raise self.erro
        return {"keys": list(self.chaves)}


@pytest.fixture
def jwks(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", URL_PROJETO)
    monkeypatch.setattr(settings, "supabase_jwt_secret", SEGREDO_DEV)
    falso = JwksFalso()
    # cooldown 0: em produção o PyJWT espera 30 s entre buscas forçadas por `kid` novo.
    cliente = jwt.PyJWKClient(f"{EMISSOR}/.well-known/jwks.json", cache_keys=True, cooldown_duration=0)
    cliente.fetch_data = falso.buscar
    urls_pedidas: list[str] = []

    def cliente_falso(url: str) -> jwt.PyJWKClient:
        urls_pedidas.append(url)
        return cliente

    monkeypatch.setattr(security, "_cliente_jwks", cliente_falso)
    falso.urls_pedidas = urls_pedidas
    return falso


@pytest.fixture
def chave(jwks):
    privada, jwk = _nova_chave("chave-1")
    jwks.chaves.append(jwk)
    return privada


def _claims(**extra) -> dict:
    agora = int(time.time())
    claims = {
        "sub": str(uuid.uuid4()),
        "aud": "authenticated",
        "iss": EMISSOR,
        "iat": agora,
        "exp": agora + 3600,
        "role": "authenticated",
    }
    claims.update(extra)
    return {k: v for k, v in claims.items() if v is not None}


def _token_es256(privada, kid: str = "chave-1", **extra) -> tuple[str, dict]:
    claims = _claims(**extra)
    return jwt.encode(claims, privada, algorithm="ES256", headers={"kid": kid}), claims


def _status(token: str) -> int:
    with pytest.raises(HTTPException) as erro:
        security.validar_token(token)
    return erro.value.status_code


# --- Token real do Supabase (ES256) -------------------------------------------


def test_token_do_projeto_valido_devolve_o_sub(chave, jwks):
    token, claims = _token_es256(chave)
    assert security.validar_token(token) == uuid.UUID(claims["sub"])
    assert jwks.urls_pedidas == [f"{EMISSOR}/.well-known/jwks.json"]


def test_url_do_projeto_com_barra_no_fim_funciona(chave, jwks, monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", URL_PROJETO + "/")
    token, claims = _token_es256(chave)
    assert security.validar_token(token) == uuid.UUID(claims["sub"])


def test_chaves_ficam_em_cache_entre_requisicoes(chave, jwks):
    for _ in range(3):
        token, _claims_ = _token_es256(chave)
        security.validar_token(token)
    assert jwks.buscas == 1


def test_chave_nova_no_projeto_renova_o_jwks(chave, jwks):
    token, _ = _token_es256(chave)
    security.validar_token(token)

    # O Supabase passou a assinar com uma chave nova (rotação).
    privada_nova, jwk_novo = _nova_chave("chave-2")
    jwks.chaves.append(jwk_novo)
    token_novo, claims = _token_es256(privada_nova, kid="chave-2")

    assert security.validar_token(token_novo) == uuid.UUID(claims["sub"])
    assert jwks.buscas == 2


def test_token_expirado_da_401(chave):
    token, _ = _token_es256(chave, exp=int(time.time()) - 120)
    assert _status(token) == 401


def test_relogio_da_maquina_atrasado_nao_recusa_token_recem_emitido(chave):
    # Bug de 2026-11-07: relógio do PC 12 min atrasado; o `iat` do Supabase
    # parecia "do futuro" e todo login real dava 401.
    agora = int(time.time())
    token, claims = _token_es256(chave, iat=agora + 729, exp=agora + 729 + 3600)
    assert security.validar_token(token) == uuid.UUID(claims["sub"])


def test_tolerancia_de_relogio_e_pequena(chave):
    agora = int(time.time())
    vencido_ha_pouco, claims = _token_es256(chave, exp=agora - 10)
    assert security.validar_token(vencido_ha_pouco) == uuid.UUID(claims["sub"])
    vencido_ha_mais, _ = _token_es256(chave, exp=agora - 120)
    assert _status(vencido_ha_mais) == 401


def test_motivo_da_recusa_vai_para_o_log_sem_o_token(chave, caplog):
    token, _ = _token_es256(chave, aud="anon")
    with caplog.at_level("WARNING", logger="app.core.security"):
        assert _status(token) == 401
    assert "InvalidAudienceError" in caplog.text
    assert token not in caplog.text


def test_chave_desconhecida_da_401(chave):
    outra_privada, _ = _nova_chave("chave-de-outro-projeto")
    token, _ = _token_es256(outra_privada, kid="chave-de-outro-projeto")
    assert _status(token) == 401


def test_assinatura_com_kid_valido_mas_chave_errada_da_401(chave):
    impostora, _ = _nova_chave("chave-1")
    token, _ = _token_es256(impostora, kid="chave-1")
    assert _status(token) == 401


def test_outro_emissor_da_401(chave):
    token, _ = _token_es256(chave, iss="https://outro.supabase.co/auth/v1")
    assert _status(token) == 401


def test_sem_emissor_da_401(chave):
    token, _ = _token_es256(chave, iss=None)
    assert _status(token) == 401


def test_audiencia_errada_da_401(chave):
    token, _ = _token_es256(chave, aud="anon")
    assert _status(token) == 401


def test_sem_sub_da_401(chave):
    token, _ = _token_es256(chave, sub=None)
    assert _status(token) == 401


def test_sub_que_nao_e_uuid_da_401(chave):
    token, _ = _token_es256(chave, sub="nao-e-um-uuid")
    assert _status(token) == 401


def test_jwks_inacessivel_da_503(jwks):
    jwks.erro = jwt.PyJWKClientConnectionError("sem rede")
    privada, _ = _nova_chave("chave-1")
    token, _ = _token_es256(privada)
    with pytest.raises(HTTPException) as erro:
        security.validar_token(token)
    assert erro.value.status_code == 503
    assert "login" in erro.value.detail


def test_sem_url_do_projeto_configurada_da_503(chave, monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    token, _ = _token_es256(chave)
    assert _status(token) == 503


# --- Token de desenvolvimento (HS256) -----------------------------------------


def _token_dev(segredo: str = SEGREDO_DEV, **extra) -> tuple[str, dict]:
    claims = _claims(iss=None, **extra)
    return jwt.encode(claims, segredo, algorithm="HS256"), claims


def test_token_de_desenvolvimento_valido_devolve_o_sub(jwks):
    token, claims = _token_dev()
    assert security.validar_token(token) == uuid.UUID(claims["sub"])
    assert jwks.buscas == 0


def test_token_de_desenvolvimento_com_segredo_errado_da_401(jwks):
    token, _ = _token_dev(segredo="outro-segredo-tambem-com-mais-de-32-bytes")
    assert _status(token) == 401


def test_token_de_desenvolvimento_expirado_da_401(jwks):
    token, _ = _token_dev(exp=int(time.time()) - 120)
    assert _status(token) == 401


def test_token_de_desenvolvimento_recusado_sem_segredo_configurado(jwks, monkeypatch):
    monkeypatch.setattr(settings, "supabase_jwt_secret", "")
    token, _ = _token_dev()
    assert _status(token) == 401


# --- Formatos inválidos e ataques de algoritmo --------------------------------


def test_texto_que_nao_e_jwt_da_401(jwks):
    assert _status("isto-nao-e-um-token") == 401


def test_algoritmo_none_da_401(jwks):
    token = jwt.encode(_claims(), None, algorithm="none")
    assert _status(token) == 401


def test_hs256_assinado_com_a_chave_publica_do_projeto_da_401(chave, jwks, monkeypatch):
    # Ataque clássico de confusão de algoritmo: usar a chave pública como segredo HMAC.
    # O PyJWT se recusa a assinar assim, então o token é montado à mão.
    monkeypatch.setattr(settings, "supabase_jwt_secret", "")
    publica = json.dumps(jwks.chaves[0]).encode()

    def b64(dados: bytes) -> str:
        return base64.urlsafe_b64encode(dados).rstrip(b"=").decode()

    cabecalho = b64(json.dumps({"alg": "HS256", "typ": "JWT", "kid": "chave-1"}).encode())
    corpo = b64(json.dumps(_claims()).encode())
    assinatura = b64(hmac.new(publica, f"{cabecalho}.{corpo}".encode(), hashlib.sha256).digest())
    assert _status(f"{cabecalho}.{corpo}.{assinatura}") == 401


# --- Pela dependência do FastAPI ----------------------------------------------


@pytest.fixture
def app_protegida():
    app = FastAPI()

    @app.get("/eu")
    def eu(usuario_id: uuid.UUID = Depends(security.get_current_user_id)):
        return {"usuario_id": str(usuario_id)}

    return TestClient(app)


def test_rota_protegida_aceita_token_do_projeto(app_protegida, chave):
    token, claims = _token_es256(chave)
    resposta = app_protegida.get("/eu", headers={"Authorization": f"Bearer {token}"})
    assert resposta.status_code == 200
    assert resposta.json() == {"usuario_id": claims["sub"]}


def test_rota_protegida_recusa_token_expirado_com_401(app_protegida, chave):
    token, _ = _token_es256(chave, exp=int(time.time()) - 120)
    resposta = app_protegida.get("/eu", headers={"Authorization": f"Bearer {token}"})
    assert resposta.status_code == 401
    assert resposta.json() == {"detail": "Token inválido ou expirado."}


def test_rota_protegida_com_jwks_fora_do_ar_responde_503_estruturado(app_protegida, chave, jwks):
    token, _ = _token_es256(chave)
    jwks.erro = jwt.PyJWKClientConnectionError("sem rede")
    resposta = app_protegida.get("/eu", headers={"Authorization": f"Bearer {token}"})
    assert resposta.status_code == 503
    assert "detail" in resposta.json()


def test_rota_protegida_sem_token_e_recusada(app_protegida):
    resposta = app_protegida.get("/eu")
    assert resposta.status_code in (401, 403)
