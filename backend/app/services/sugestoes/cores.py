"""Regras de cores: ousadia de pares, ajuste de tonalidade e limite de cores.

Ver `docs/regras-sugestoes.md`, seção 1.
"""

from itertools import combinations

from app.services.sugestoes.tipos import PecaMotor, PreferenciasMotor

NEUTROS = frozenset({"Preto", "Branco", "Cinza", "Bege", "Marrom", "Azul-marinho"})

# Posição da família na roda de 6: Vermelho → Laranja → Amarelo → Verde → Azul → Roxo.
FAMILIA = {
    "Vermelho": 0,
    "Vinho": 0,
    "Rosa": 0,
    "Laranja": 1,
    "Amarelo": 2,
    "Verde": 3,
    "Azul": 4,
    "Azul-claro": 4,
    "Roxo": 5,
}

# Mesma tonalidade sugerida de `coresFixas` no app (peca_opcoes.dart).
TONALIDADE_PADRAO = {
    "Preto": "Escura",
    "Branco": "Clara",
    "Cinza": "Neutra",
    "Bege": "Neutra",
    "Marrom": "Escura",
    "Vermelho": "Vibrante",
    "Vinho": "Escura",
    "Laranja": "Vibrante",
    "Amarelo": "Vibrante",
    "Verde": "Vibrante",
    "Azul-marinho": "Escura",
    "Azul": "Vibrante",
    "Azul-claro": "Pastel",
    "Rosa": "Pastel",
    "Roxo": "Vibrante",
}

TONALIDADES_QUE_SUAVIZAM = frozenset({"Pastel", "Escura"})
MAX_CORES_NAO_NEUTRAS = 3


def cor_reconhecida(peca: PecaMotor) -> str | None:
    """Nome da cor se estiver na lista fixa; texto livre ou vazio = sem cor."""
    cor = (peca.cor or "").strip()
    return cor if cor in NEUTROS or cor in FAMILIA else None


def tonalidade_efetiva(peca: PecaMotor) -> str | None:
    tonalidade = (peca.tonalidade or "").strip()
    if tonalidade:
        return tonalidade
    cor = cor_reconhecida(peca)
    return TONALIDADE_PADRAO.get(cor) if cor else None


def eh_neutra(peca: PecaMotor) -> bool:
    cor = cor_reconhecida(peca)
    if cor is None:
        return False
    return cor in NEUTROS or tonalidade_efetiva(peca) == "Neutra"


def ousadia_par(a: PecaMotor, b: PecaMotor) -> int | None:
    """Ousadia de 0 a 4; `None` se alguma das peças não tem cor reconhecida."""
    cor_a, cor_b = cor_reconhecida(a), cor_reconhecida(b)
    if cor_a is None or cor_b is None:
        return None
    if eh_neutra(a) or eh_neutra(b) or cor_a == cor_b:
        return 0
    distancia = abs(FAMILIA[cor_a] - FAMILIA[cor_b])
    distancia = min(distancia, 6 - distancia)
    ousadia = distancia + 1
    tom_a, tom_b = tonalidade_efetiva(a), tonalidade_efetiva(b)
    if tom_a == tom_b and tom_a in TONALIDADES_QUE_SUAVIZAM:
        ousadia = max(1, ousadia - 1)
    return ousadia


def cores_nao_neutras(pecas: tuple[PecaMotor, ...] | list[PecaMotor]) -> set[str]:
    return {cor_reconhecida(p) for p in pecas if cor_reconhecida(p) and not eh_neutra(p)}


def ousadia_maxima(criatividade: int) -> int:
    return criatividade - 1


def par_favorito(a: PecaMotor, b: PecaMotor, prefs: PreferenciasMotor) -> frozenset[str] | None:
    cor_a, cor_b = cor_reconhecida(a), cor_reconhecida(b)
    if cor_a is None or cor_b is None or cor_a == cor_b:
        return None
    par = frozenset({cor_a, cor_b})
    return par if par in prefs.pares_favoritos else None


def par_permitido(a: PecaMotor, b: PecaMotor, prefs: PreferenciasMotor) -> bool:
    """O par cabe na criatividade, ou é um par de cores favorito."""
    ousadia = ousadia_par(a, b)
    if ousadia is None or ousadia <= ousadia_maxima(prefs.criatividade):
        return True
    return par_favorito(a, b, prefs) is not None


def avaliar_cores(
    pecas: tuple[PecaMotor, ...] | list[PecaMotor], prefs: PreferenciasMotor
) -> tuple[bool, int, frozenset[frozenset[str]]]:
    """(válido, ousadia do look sem pares favoritos, pares favoritos presentes)."""
    if len(cores_nao_neutras(pecas)) > MAX_CORES_NAO_NEUTRAS:
        return False, 0, frozenset()
    ousadia_look = 0
    favoritos: set[frozenset[str]] = set()
    for a, b in combinations(pecas, 2):
        favorito = par_favorito(a, b, prefs)
        if favorito is not None:
            favoritos.add(favorito)
            continue
        ousadia = ousadia_par(a, b)
        if ousadia is not None:
            ousadia_look = max(ousadia_look, ousadia)
    valido = ousadia_look <= ousadia_maxima(prefs.criatividade)
    return valido, ousadia_look, frozenset(favoritos)
