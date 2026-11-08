"""Validação do JWT emitido pelo Supabase Auth.

O `user_id` de toda requisição autenticada vem daqui — nunca do corpo
ou da query string. Ver CLAUDE.md, seção "Auth".

Dois tipos de token são aceitos:
- **Token real do Supabase** (ES256): verificado com as chaves públicas do
  projeto (JWKS), conferindo emissor, audiência e expiração. Algoritmo
  confirmado no JWKS do projeto em 2026-11-07 (E9.F1.1).
- **Token de desenvolvimento** (HS256): assinado com `SUPABASE_JWT_SECRET` pelo
  `scripts/gerar_token_teste.py`. Só é aceito se o segredo estiver configurado;
  em produção ele fica vazio (E9.F3.2).
"""

import logging
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import settings

_log = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=True)

# Diferença de relógio tolerada entre o servidor da API e o do Supabase.
# Além disso, o `iat` (emitido em) não é conferido: com o relógio da máquina
# atrasado, um token recém-emitido parece "do futuro" e seria recusado
# (aconteceu em 2026-11-07 com o relógio do PC 12 min atrasado). O `iat` não
# protege nada que a assinatura e o `exp` já não protejam.
_TOLERANCIA_RELOGIO_S = 30
_OPCOES_TEMPO = {"verify_iat": False}

# Algoritmos que o projeto Supabase usa para assinar (conferido no JWKS real).
ALGORITMOS_SUPABASE = ["ES256"]
ALGORITMO_DEV = "HS256"
AUDIENCIA = "authenticated"

# Cache das chaves: renovado a cada 10 min ou quando chega um `kid` desconhecido.
_JWKS_VALIDADE_S = 600
_JWKS_TIMEOUT_S = 5

_clientes_jwks: dict[str, jwt.PyJWKClient] = {}


def _cliente_jwks(url_jwks: str) -> jwt.PyJWKClient:
    """Um cliente por URL, guardado em memória para não buscar o JWKS a cada requisição."""
    cliente = _clientes_jwks.get(url_jwks)
    if cliente is None:
        cliente = jwt.PyJWKClient(
            url_jwks,
            cache_keys=True,
            lifespan=_JWKS_VALIDADE_S,
            timeout=_JWKS_TIMEOUT_S,
        )
        _clientes_jwks[url_jwks] = cliente
    return cliente


def _nao_autorizado(detalhe: str = "Token inválido ou expirado.") -> HTTPException:
    return HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=detalhe)


def _indisponivel(detalhe: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=detalhe)


def _decodificar_supabase(token: str) -> dict:
    url_projeto = settings.supabase_url.rstrip("/")
    if not url_projeto:
        raise _indisponivel("Autenticação não configurada no servidor.")

    try:
        chave = _cliente_jwks(f"{url_projeto}/auth/v1/.well-known/jwks.json").get_signing_key_from_jwt(token)
    except jwt.PyJWKClientConnectionError as exc:
        raise _indisponivel("Não foi possível verificar o login agora. Tente de novo em instantes.") from exc
    except jwt.PyJWKClientError as exc:
        # Chave desconhecida mesmo depois de renovar o JWKS: token de outro projeto ou forjado.
        raise _nao_autorizado() from exc

    return jwt.decode(
        token,
        chave.key,
        algorithms=ALGORITMOS_SUPABASE,
        audience=AUDIENCIA,
        issuer=f"{url_projeto}/auth/v1",
        leeway=_TOLERANCIA_RELOGIO_S,
        options={"require": ["exp", "iss", "aud", "sub"], **_OPCOES_TEMPO},
    )


def _decodificar_dev(token: str) -> dict:
    return jwt.decode(
        token,
        settings.supabase_jwt_secret,
        algorithms=[ALGORITMO_DEV],
        audience=AUDIENCIA,
        leeway=_TOLERANCIA_RELOGIO_S,
        options={"require": ["exp", "aud", "sub"], **_OPCOES_TEMPO},
    )


def validar_token(token: str) -> UUID:
    """Valida o token e devolve o `sub` como UUID; qualquer problema vira 401 (ou 503)."""
    try:
        algoritmo = jwt.get_unverified_header(token).get("alg")
    except jwt.PyJWTError as exc:
        raise _nao_autorizado() from exc

    # O algoritmo do cabeçalho só escolhe o caminho; cada caminho aceita uma lista
    # fixa de algoritmos, então trocar o `alg` no token não burla a verificação.
    try:
        if algoritmo in ALGORITMOS_SUPABASE:
            payload = _decodificar_supabase(token)
        elif algoritmo == ALGORITMO_DEV and settings.supabase_jwt_secret:
            payload = _decodificar_dev(token)
        else:
            _log.warning("Token recusado: algoritmo %r não aceito", algoritmo)
            raise _nao_autorizado()
    except jwt.PyJWTError as exc:
        # Só o tipo e a mensagem do erro, nunca o token.
        _log.warning("Token recusado (%s): %s", type(exc).__name__, exc)
        raise _nao_autorizado() from exc

    try:
        return UUID(str(payload["sub"]))
    except (KeyError, ValueError) as exc:
        raise _nao_autorizado("Token sem identificação de usuário.") from exc


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
) -> UUID:
    """Dependência do FastAPI: o id do usuário logado, vindo do token."""
    return validar_token(credentials.credentials)
