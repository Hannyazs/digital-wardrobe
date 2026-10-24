"""Vocabulário que liga o texto de uma etiqueta às categorias e cores do app.

Tudo em minúsculas e sem acento (ver `normalizar`). As categorias e as cores
são as listas fixas de `mobile/lib/core/constants/peca_opcoes.dart`
(`categoriasFixas`, `coresFixas`): se uma entrar ou sair lá, muda aqui também.
Palavra fora do vocabulário não é adivinhada: a etiqueta vira lacuna.
"""

import re
import unicodedata

_PALAVRAS_POR_CATEGORIA: dict[str, tuple[str, ...]] = {
    "Camisetas": ("camiseta", "tshirt", "tee", "camisetao"),
    "Camisas": ("camisa", "camisao"),
    "Blusas": ("blusa", "top", "cropped", "body", "bata", "regatinha"),
    "Regatas": ("regata", "musculosa"),
    "Suéteres": ("sueter", "pulover", "tricot", "moletom"),
    "Calças": ("calca", "legging", "jogger", "pantalona", "pantacourt", "cargo"),
    "Shorts": ("short", "bermuda", "calcao", "calcoes"),
    "Saias": ("saia", "minissaia"),
    "Vestidos": ("vestido", "chemise"),
    "Macacões": ("macacao", "macacoes", "macaquinho", "jardineira"),
    "Casacos": (
        "jaqueta", "casaco", "blazer", "cardigan", "colete", "sobretudo", "trench",
        "parka", "bomber", "jaquetao", "kimono", "poncho", "cardiga",
    ),
    "Sapatos": (
        "tenis", "sapato", "sapatilha", "bota", "botina", "sandalia", "salto",
        "scarpin", "mocassim", "chinelo", "rasteirinha", "sapatenis", "oxford",
        "coturno", "alpargata", "papete", "mule",
    ),
    "Acessórios": (
        "bolsa", "cinto", "colar", "brinco", "pulseira", "bracelete", "relogio",
        "oculos", "chapeu", "bone", "lenco", "cachecol", "meia", "anel", "gravata",
        "mochila", "carteira", "tiara", "luva", "boina", "viseira", "bandana", "joia", "bijuteria",
    ),
}

CATEGORIA_POR_PALAVRA: dict[str, str] = {
    palavra: categoria
    for categoria, palavras in _PALAVRAS_POR_CATEGORIA.items()
    for palavra in palavras
}

_PALAVRAS_POR_COR: dict[str, tuple[str, ...]] = {
    "Preto": ("preto", "preta", "pretos", "pretas", "negro", "negra"),
    "Branco": ("branco", "branca", "brancos", "brancas", "off", "offwhite"),
    "Cinza": ("cinza", "cinzas", "grafite", "chumbo"),
    "Bege": ("bege", "beges", "nude", "creme", "caqui", "areia"),
    "Marrom": ("marrom", "marrons", "caramelo", "chocolate"),
    "Vermelho": ("vermelho", "vermelha", "vermelhos", "vermelhas"),
    "Vinho": ("vinho", "bordo", "bordeaux", "marsala"),
    "Laranja": ("laranja", "laranjas", "terracota"),
    "Amarelo": ("amarelo", "amarela", "amarelos", "amarelas", "mostarda"),
    "Verde": ("verde", "verdes", "oliva"),
    "Azul": ("azul", "azuis"),
    "Rosa": ("rosa", "rosas", "pink", "magenta", "fucsia"),
    "Roxo": ("roxo", "roxa", "roxos", "roxas", "lilas", "violeta", "purpura"),
}

COR_POR_PALAVRA: dict[str, str] = {
    palavra: cor for cor, palavras in _PALAVRAS_POR_COR.items() for palavra in palavras
}

# Cores de duas palavras: "azul marinho" / "azul-marinho" e "azul claro".
COR_POR_DUPLA: dict[tuple[str, str], str] = {
    ("azul", "marinho"): "Azul-marinho",
    ("azul", "claro"): "Azul-claro",
    ("azul", "bebe"): "Azul-claro",
    ("azul", "celeste"): "Azul-claro",
}
# "marinho" e "celeste" sozinhos já dizem a cor.
COR_POR_PALAVRA["marinho"] = "Azul-marinho"
COR_POR_PALAVRA["celeste"] = "Azul-claro"

# Palavras que não dizem nada sobre a peça (não contam como "palavra restante").
PALAVRAS_VAZIAS = frozenset(
    {
        "de", "da", "do", "das", "dos", "com", "sem", "em", "no", "na", "nos", "nas", "e", "ou",
        "a", "o", "as", "os", "um", "uma", "uns", "umas", "para", "por", "tipo", "estilo",
        "bem", "mais", "muito", "claro", "escuro", "escura", "clara", "tom",
    }
)


def normalizar(texto: str) -> str:
    """Minúsculas, sem acento, só letras e números separados por um espaço
    ("Calça jeans-azul!" -> "calca jeans azul")."""
    sem_acento = "".join(
        c for c in unicodedata.normalize("NFD", texto.casefold()) if unicodedata.category(c) != "Mn"
    )
    return " ".join(re.sub(r"[^a-z0-9]+", " ", sem_acento).split())


def formas_da_palavra(palavra: str) -> tuple[str, ...]:
    """A palavra e o que sobra sem o plural ("calcas" -> "calca", "macacoes" -> "macaco")."""
    formas = [palavra]
    if palavra.endswith("es") and len(palavra) > 4:
        formas.append(palavra[:-2])
    if palavra.endswith("s") and len(palavra) > 3:
        formas.append(palavra[:-1])
    return tuple(formas)


# Tipo dentro de categorias largas (Sapatos e Acessórios juntam coisas que não se
# substituem: uma bota não é um tênis, uma meia não é uma bolsa). Só as palavras
# abaixo definem tipo; "sapato" sozinho é genérico e não restringe nada.
_PALAVRAS_POR_TIPO: dict[str, tuple[str, ...]] = {
    "tenis": ("tenis", "sapatenis"),
    "bota": ("bota", "botina", "coturno"),
    "sandalia": ("sandalia", "rasteirinha", "chinelo", "papete"),
    "salto": ("salto", "scarpin"),
    "sapatilha": ("sapatilha",),
    "mocassim": ("mocassim", "oxford", "alpargata"),
    "bolsa": ("bolsa", "mochila", "carteira"),
    "cinto": ("cinto",),
    "joia": ("colar", "brinco", "pulseira", "bracelete", "anel", "joia", "bijuteria"),
    "relogio": ("relogio",),
    "oculos": ("oculos",),
    "chapeu": ("chapeu", "bone", "boina", "viseira", "tiara"),
    "lenco": ("lenco", "cachecol", "bandana", "gravata"),
    "meia": ("meia",),
    "luva": ("luva",),
}

TIPO_POR_PALAVRA: dict[str, str] = {
    palavra: tipo for tipo, palavras in _PALAVRAS_POR_TIPO.items() for palavra in palavras
}


def tipo_do_texto(texto_normalizado: str) -> str | None:
    """Tipo da primeira palavra que define um (ex.: "botas de cano alto" -> "bota").
    `None` se nenhuma define: o tipo é desconhecido, não "qualquer"."""
    for palavra in texto_normalizado.split():
        for forma in formas_da_palavra(palavra):
            if forma in TIPO_POR_PALAVRA:
                return TIPO_POR_PALAVRA[forma]
    return None
