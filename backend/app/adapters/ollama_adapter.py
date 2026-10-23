"""Extração de metadados da peça via Gemma 3 rodando no Ollama local.

Qualquer falha (Ollama fora do ar, tempo esgotado, resposta inválida) vira
sugestão vazia: o usuário preenche à mão — ver CLAUDE.md, convenção "Nada de
chamada de IA sem timeout e fallback". A extração é sempre sugestão.
"""

import base64
import json
import logging

import httpx

from app.core.config import settings
from app.schemas.peca import PecaBase

logger = logging.getLogger(__name__)

# Listas fixas: espelham mobile/lib/core/constants/peca_opcoes.dart
# (categoriasFixas, coresFixas, tonalidadesFixas). Mudar uma exige mudar a outra.
CATEGORIAS = [
    "Camisetas", "Camisas", "Blusas", "Regatas", "Suéteres", "Calças", "Shorts", "Saias",
    "Vestidos", "Macacões", "Casacos", "Sapatos", "Acessórios",
]
CORES = [
    "Preto", "Branco", "Cinza", "Bege", "Marrom", "Vermelho", "Vinho", "Laranja",
    "Amarelo", "Verde", "Azul-marinho", "Azul", "Azul-claro", "Rosa", "Roxo",
]
TONALIDADES = ["Escura", "Clara", "Vibrante", "Pastel", "Neutra"]

SUBCATEGORIA_MAX = 40

PROMPT = (
    "Você analisa a foto de uma peça de roupa e descreve a peça em português.\n"
    f"- categoria: uma destas opções: {', '.join(CATEGORIAS)}.\n"
    "- subcategoria: descrição curta do modelo da peça, por exemplo "
    '"gola V", "manga curta", "skinny", "cano alto".\n'
    f"- cor_principal: uma destas opções: {', '.join(CORES)}.\n"
    f"- tonalidade_cor: uma destas opções: {', '.join(TONALIDADES)}.\n"
    "Responda só com o JSON pedido."
)

_SCHEMA = {
    "type": "object",
    "properties": {
        "categoria": {"type": "string"},
        "subcategoria": {"type": "string"},
        "cor_principal": {"type": "string"},
        "tonalidade_cor": {"type": "string"},
    },
    "required": ["categoria", "subcategoria", "cor_principal", "tonalidade_cor"],
}

# Trechos da própria instrução que o modelo pequeno às vezes devolve no lugar
# de uma descrição.
_ECOS_DA_INSTRUCAO = ("texto curto", "descrição curta", "descricao curta", "modelo da peça")


def _vazia() -> PecaBase:
    return PecaBase(categoria="")


def _da_lista(valor: object, permitidos: list[str]) -> str | None:
    if not isinstance(valor, str):
        return None
    texto = valor.strip().casefold()
    for permitido in permitidos:
        if permitido.casefold() == texto:
            return permitido
    return None


def _subcategoria(valor: object) -> str | None:
    if not isinstance(valor, str):
        return None
    texto = valor.strip()
    if not texto or any(eco in texto.casefold() for eco in _ECOS_DA_INSTRUCAO):
        return None
    return texto[:SUBCATEGORIA_MAX]


def _validar(dados: dict) -> PecaBase:
    return PecaBase(
        categoria=_da_lista(dados.get("categoria"), CATEGORIAS) or "",
        subcategoria=_subcategoria(dados.get("subcategoria")),
        cor_principal=_da_lista(dados.get("cor_principal"), CORES),
        tonalidade_cor=_da_lista(dados.get("tonalidade_cor"), TONALIDADES),
    )


def extract_metadata(
    imagem_bytes: bytes, transport: httpx.BaseTransport | None = None
) -> PecaBase:
    """`transport` existe só para os testes simularem o Ollama."""
    corpo = {
        "model": settings.ollama_modelo,
        "stream": False,
        "format": _SCHEMA,
        "messages": [
            {
                "role": "user",
                "content": PROMPT,
                "images": [base64.b64encode(imagem_bytes).decode("ascii")],
            }
        ],
    }
    try:
        with httpx.Client(timeout=settings.ollama_timeout_s, transport=transport) as cliente:
            resposta = cliente.post(f"{settings.ollama_url}/api/chat", json=corpo)
            resposta.raise_for_status()
        dados = json.loads(resposta.json()["message"]["content"])
        if not isinstance(dados, dict):
            raise ValueError("resposta do modelo não é um objeto JSON")
        return _validar(dados)
    except Exception as erro:
        logger.warning("Sugestão por IA indisponível (%s): %s", type(erro).__name__, erro)
        return _vazia()
