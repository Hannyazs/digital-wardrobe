"""Gera um JWT de teste (HS256), assinado com o SUPABASE_JWT_SECRET do .env local.

Uso apenas para desenvolvimento. A API aceita esse token enquanto
SUPABASE_JWT_SECRET estiver preenchido (ver app/core/security.py); os tokens
reais do Supabase (ES256) são validados pelas chaves públicas do projeto.
Em produção o segredo fica vazio e este script deixa de servir.

Uso:
    python scripts/gerar_token_teste.py
    python scripts/gerar_token_teste.py --usuario-id <uuid> --dias 7
"""

import argparse
import os
import time
import uuid

import jwt
from dotenv import load_dotenv

load_dotenv()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--usuario-id", default=None, help="UUID do usuário de teste (default: aleatório)")
    parser.add_argument("--dias", type=int, default=30, help="Validade do token em dias (default: 30)")
    args = parser.parse_args()

    if os.getenv("AMBIENTE", "desenvolvimento") == "producao":
        raise SystemExit("Token de teste é só para desenvolvimento (AMBIENTE=producao).")

    secret = os.getenv("SUPABASE_JWT_SECRET")
    if not secret:
        raise SystemExit("SUPABASE_JWT_SECRET não encontrado no .env")

    usuario_id = args.usuario_id or str(uuid.uuid4())
    payload = {
        "sub": usuario_id,
        "aud": "authenticated",
        "exp": int(time.time()) + args.dias * 24 * 60 * 60,
    }
    token = jwt.encode(payload, secret, algorithm="HS256")

    print(f"usuario_id: {usuario_id}")
    print(f"validade:   {args.dias} dias")
    print("token:")
    print(token)


if __name__ == "__main__":
    main()
