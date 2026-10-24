"""Extração de metadados da peça via Gemma 3 rodando no Ollama local.

Qualquer falha (Ollama fora do ar, tempo esgotado, resposta inválida) vira
sugestão vazia: o usuário preenche à mão — ver CLAUDE.md, convenção "Nada de
chamada de IA sem timeout e fallback". A extração é sempre sugestão.
"""

import base64
import io
import json
import logging
import unicodedata

import httpx
from PIL import Image

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


def _conversar(
    prompt: str,
    schema: dict,
    imagem_bytes: bytes | list[bytes],
    transport: httpx.BaseTransport | None,
) -> dict:
    """Pede ao Ollama uma resposta estruturada sobre uma ou mais imagens. Levanta
    exceção em qualquer falha (os chamadores a transformam em resultado vazio)."""
    imagens = [imagem_bytes] if isinstance(imagem_bytes, bytes) else imagem_bytes
    corpo = {
        "model": settings.ollama_modelo,
        "stream": False,
        "format": schema,
        "messages": [
            {
                "role": "user",
                "content": prompt,
                "images": [base64.b64encode(imagem).decode("ascii") for imagem in imagens],
            }
        ],
    }
    with httpx.Client(timeout=settings.ollama_timeout_s, transport=transport) as cliente:
        resposta = cliente.post(f"{settings.ollama_url}/api/chat", json=corpo)
        resposta.raise_for_status()
    dados = json.loads(resposta.json()["message"]["content"])
    if not isinstance(dados, dict):
        raise ValueError("resposta do modelo não é um objeto JSON")
    return dados


def extract_metadata(
    imagem_bytes: bytes, transport: httpx.BaseTransport | None = None
) -> PecaBase:
    """`transport` existe só para os testes simularem o Ollama."""
    try:
        return _validar(_conversar(PROMPT, _SCHEMA, imagem_bytes, transport))
    except Exception as erro:
        logger.warning("Sugestão por IA indisponível (%s): %s", type(erro).__name__, erro)
        return _vazia()


# --- E8.F4.1: peças visíveis numa referência do mural

ETIQUETA_MAX = 40
ETIQUETAS_MAX = 6

PROMPT_PECAS_VISIVEIS = (
    "Você olha a foto de um look e lista só as peças de roupa, calçados e acessórios "
    "que a pessoa está vestindo ou carregando.\n"
    f"Liste até {ETIQUETAS_MAX} itens, em português. Cada item é a peça e a cor, em poucas "
    'palavras, por exemplo: "camiseta branca", "calça jeans", "tênis preto".\n'
    "Ignore tudo que é cenário ou ambiente: chão, cascalho, pedra, madeira, parede, grama, "
    "areia, árvore, céu, rua, móveis, objetos ao redor.\n"
    "Preste atenção ao comprimento: peça de baixo curta (acima do joelho) é \"short\", "
    "não \"calça\"; e ao tipo do calçado (tênis, bota, sandália, salto).\n"
    "Não repita peças e não invente o que não dá para ver. Responda só com o JSON pedido."
)

# Palavras de cenário que o modelo às vezes lista mesmo sendo proibido no prompt.
# Vale a primeira palavra do item (sem acento): "chão de cascalho" sai, mas
# "bolsa de madeira" fica, porque é uma peça.
_AMBIENTE = frozenset(
    {
        "chao", "piso", "solo", "terra", "cascalho", "pedra", "pedras", "pedregulho", "brita",
        "madeira", "parede", "muro", "tijolo", "tijolos", "concreto", "cimento", "asfalto",
        "calcada", "rua", "grama", "gramado", "areia", "arvore", "arvores", "folhas", "planta",
        "plantas", "flores", "ceu", "nuvens", "fundo", "cenario", "ambiente", "movel", "moveis",
        "cadeira", "mesa", "sofa", "porta", "janela", "escada", "banco", "cerca", "tapete",
    }
)

_SCHEMA_PECAS_VISIVEIS = {
    "type": "object",
    "properties": {"pecas": {"type": "array", "items": {"type": "string"}}},
    "required": ["pecas"],
}

# Trechos da instrução que o modelo pequeno às vezes devolve como se fossem peças.
_ECOS_PECAS_VISIVEIS = ("poucas palavras", "peça e a cor", "peca e a cor", "em português")


def _sem_acento(texto: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", texto) if unicodedata.category(c) != "Mn")


def _eh_ambiente(texto: str) -> bool:
    primeira = _sem_acento(texto.casefold()).split(" ", 1)[0].strip(",.;:-")
    return primeira in _AMBIENTE


def _etiquetas(valor: object) -> list[str]:
    if not isinstance(valor, list):
        raise ValueError("`pecas` não é uma lista")
    etiquetas: list[str] = []
    vistas: set[str] = set()
    for item in valor:
        if not isinstance(item, str):
            continue
        texto = " ".join(item.split())
        chave = texto.casefold()
        if not texto or chave in vistas or any(eco in chave for eco in _ECOS_PECAS_VISIVEIS):
            continue
        if _eh_ambiente(texto):
            continue
        vistas.add(chave)
        etiquetas.append(texto[:ETIQUETA_MAX])
        if len(etiquetas) == ETIQUETAS_MAX:
            break
    return etiquetas


def listar_pecas_visiveis(
    imagem_bytes: bytes, transport: httpx.BaseTransport | None = None
) -> list[str]:
    """Etiquetas das peças visíveis na foto (ex.: "camiseta branca"). Sempre
    sugestão: o usuário edita. Qualquer falha vira lista vazia, sem exceção.
    `transport` existe só para os testes simularem o Ollama."""
    try:
        return _etiquetas(_conversar(PROMPT_PECAS_VISIVEIS, _SCHEMA_PECAS_VISIVEIS, imagem_bytes, transport).get("pecas"))
    except Exception as erro:
        logger.warning("Etiquetas por IA indisponíveis (%s): %s", type(erro).__name__, erro)
        return []


# --- E8.F5.2: qual peça do armário é a da referência?

LADO_MAX_PX = 512


def _reduzir(imagem_bytes: bytes) -> bytes:
    """Imagem menor (até 512 px no lado maior) em JPEG sobre fundo branco: o
    Gemma não precisa de mais, e cada chamada fica mais rápida e leve. Peças
    com fundo transparente (PNG) ganham fundo branco em vez de preto."""
    with Image.open(io.BytesIO(imagem_bytes)) as imagem:
        imagem = imagem.convert("RGBA")
        imagem.thumbnail((LADO_MAX_PX, LADO_MAX_PX))
        fundo = Image.new("RGB", imagem.size, "white")
        fundo.paste(imagem, mask=imagem.getchannel("A"))
        saida = io.BytesIO()
        fundo.save(saida, format="JPEG", quality=85)
        return saida.getvalue()


def _prompt_escolha(etiqueta: str, quantidade: int) -> str:
    return (
        "A primeira imagem é a foto de um look (a referência). As imagens seguintes são "
        f"peças do guarda-roupa, numeradas de 1 a {quantidade} na ordem em que aparecem.\n"
        f'Procure na referência a peça: "{etiqueta}".\n'
        "Escolha a peça numerada que seja do MESMO TIPO (uma bota só combina com bota, um "
        "tênis só com tênis, uma bolsa só com bolsa, um short só com short). "
        "A cor pode ser diferente: se houver duas do mesmo tipo, prefira a de cor mais parecida, "
        "mas aceite outra cor se o tipo for o mesmo.\n"
        "Se nenhuma for do mesmo tipo, responda 0. Prefira 0 a escolher um tipo diferente.\n"
        "Ignore o cenário e o fundo. Responda só com o JSON pedido: o número da peça, ou 0."
    )


def escolher_peca_parecida(
    referencia_bytes: bytes,
    etiqueta: str,
    candidatas_bytes: list[bytes],
    transport: httpx.BaseTransport | None = None,
) -> int | None:
    """Índice (a partir de 0) da candidata mais parecida com a peça `etiqueta` da
    foto de referência, ou `None` se nenhuma serve. Qualquer falha (Ollama fora do
    ar, tempo esgotado, resposta inválida ou fora do intervalo) também vira
    `None`: o chamador trata como "sem peça equivalente", nunca como erro.
    `transport` existe só para os testes simularem o Ollama."""
    if not candidatas_bytes:
        return None
    try:
        quantidade = len(candidatas_bytes)
        schema = {
            "type": "object",
            "properties": {"escolha": {"type": "integer", "minimum": 0, "maximum": quantidade}},
            "required": ["escolha"],
        }
        imagens = [_reduzir(referencia_bytes), *(_reduzir(c) for c in candidatas_bytes)]
        dados = _conversar(_prompt_escolha(etiqueta, quantidade), schema, imagens, transport)
        escolha = dados.get("escolha")
        if isinstance(escolha, bool) or not isinstance(escolha, int):
            raise ValueError("`escolha` não é um número inteiro")
        if not 0 <= escolha <= quantidade:
            raise ValueError(f"`escolha` fora do intervalo: {escolha}")
        return escolha - 1 if escolha >= 1 else None
    except Exception as erro:
        logger.warning("Comparação por IA indisponível (%s): %s", type(erro).__name__, erro)
        return None
