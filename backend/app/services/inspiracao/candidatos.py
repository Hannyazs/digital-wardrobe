"""Funil de candidatas: etiquetas da referência -> peças do armário a comparar.

Para cada etiqueta ("calça jeans azul") descobre a categoria, as cores e as
palavras que sobram ("jeans"), e escolhe até `MAX_CANDIDATAS` peças do
usuário daquela categoria, das que mais combinam às que menos combinam. A
escolha final entre elas é visual (E8.F5.2); aqui só se afunila.

Funções puras: sem banco, sem HTTP e sem `settings`. Peça evitada nunca entra.
Etiqueta sem categoria reconhecida, ou sem nenhuma peça da categoria, vira uma
lacuna com o motivo — nunca uma peça "parecida" de outra categoria.
"""

import uuid
from collections.abc import Collection, Sequence
from dataclasses import dataclass

from app.services.inspiracao.vocabulario import (
    CATEGORIA_POR_PALAVRA,
    COR_POR_DUPLA,
    COR_POR_PALAVRA,
    PALAVRAS_VAZIAS,
    formas_da_palavra,
    normalizar,
    tipo_do_texto,
)

MAX_CANDIDATAS = 4

PONTOS_COR = 2
PONTOS_PALAVRA_NA_SUBCATEGORIA = 1
# O tipo certo (bota para bota) vale mais que a cor: a cor errada ainda é a mesma peça.
PONTOS_TIPO = 3

MOTIVO_NAO_ENTENDIDA = "Não entendi a peça."
MOTIVO_SEM_PECA_DA_CATEGORIA = "Nenhuma peça dessa categoria no seu armário."
MOTIVO_SEM_PECA_DO_TIPO = "Nenhuma peça desse tipo no seu armário."


@dataclass(frozen=True)
class PecaCandidata:
    """O que o funil precisa saber de uma peça do armário."""

    id: uuid.UUID
    categoria: str
    subcategoria: str | None = None
    cor: str | None = None
    cores_extras: tuple[str, ...] = ()

    @property
    def cores(self) -> frozenset[str]:
        """A cor predominante e as secundárias (peça multicolorida)."""
        return frozenset(c for c in (self.cor, *self.cores_extras) if c)


@dataclass(frozen=True)
class Funil:
    """Resultado para uma etiqueta."""

    etiqueta: str
    categoria: str | None
    cores: tuple[str, ...]
    candidatas: tuple[uuid.UUID, ...]
    motivo_lacuna: str | None = None


def _categoria(palavras: Sequence[str]) -> str | None:
    """Categoria da primeira palavra que está no vocabulário."""
    for palavra in palavras:
        for forma in formas_da_palavra(palavra):
            if forma in CATEGORIA_POR_PALAVRA:
                return CATEGORIA_POR_PALAVRA[forma]
    return None


def _cores_e_restantes(palavras: Sequence[str]) -> tuple[tuple[str, ...], list[str]]:
    """Cores citadas (sem repetir, na ordem) e as palavras que não são cor,
    categoria nem palavra vazia."""
    cores: list[str] = []
    restantes: list[str] = []
    i = 0
    while i < len(palavras):
        palavra = palavras[i]
        if i + 1 < len(palavras) and (palavra, palavras[i + 1]) in COR_POR_DUPLA:
            cor = COR_POR_DUPLA[(palavra, palavras[i + 1])]
            i += 2
        else:
            cor = next(
                (COR_POR_PALAVRA[f] for f in formas_da_palavra(palavra) if f in COR_POR_PALAVRA),
                None,
            )
            i += 1
        if cor is not None:
            if cor not in cores:
                cores.append(cor)
            continue
        eh_categoria = any(f in CATEGORIA_POR_PALAVRA for f in formas_da_palavra(palavra))
        if not eh_categoria and palavra not in PALAVRAS_VAZIAS and len(palavra) >= 3:
            restantes.append(palavra)
    return tuple(cores), restantes


def _pontos(peca: PecaCandidata, cores: tuple[str, ...], restantes: Sequence[str]) -> int:
    pontos = PONTOS_COR if any(cor in peca.cores for cor in cores) else 0
    subcategoria = normalizar(peca.subcategoria or "")
    pontos += PONTOS_PALAVRA_NA_SUBCATEGORIA * sum(1 for palavra in restantes if palavra in subcategoria)
    return pontos


def funil_da_etiqueta(
    etiqueta: str, pecas: Sequence[PecaCandidata], evitadas: Collection[uuid.UUID] = ()
) -> Funil:
    palavras = normalizar(etiqueta).split()
    categoria = _categoria(palavras)
    if categoria is None:
        return Funil(etiqueta, None, (), (), MOTIVO_NAO_ENTENDIDA)

    cores, restantes = _cores_e_restantes(palavras)
    da_categoria = [p for p in pecas if p.categoria == categoria and p.id not in evitadas]
    if not da_categoria:
        return Funil(etiqueta, categoria, cores, (), MOTIVO_SEM_PECA_DA_CATEGORIA)

    # Dentro de categorias largas (sapatos, acessórios) o tipo manda: peça de tipo
    # conhecido e diferente do pedido não concorre. Peça sem tipo conhecido (sem
    # subcategoria, ou uma que o vocabulário não reconhece) só concorre se não
    # houver peça do tipo exato.
    tipo = tipo_do_texto(" ".join(palavras))
    tipo_da_peca = {p.id: tipo_do_texto(normalizar(p.subcategoria or "")) for p in da_categoria}
    if tipo is not None:
        do_tipo = [p for p in da_categoria if tipo_da_peca[p.id] == tipo]
        # Havendo peça do tipo exato, as de tipo desconhecido (ex.: "Adidas Gazelle")
        # não disputam com ela; sem nenhuma, elas seguem como candidatas.
        da_categoria = do_tipo or [p for p in da_categoria if tipo_da_peca[p.id] is None]
        if not da_categoria:
            return Funil(etiqueta, categoria, cores, (), MOTIVO_SEM_PECA_DO_TIPO)

    def pontos(p: PecaCandidata) -> int:
        extra = PONTOS_TIPO if tipo is not None and tipo_da_peca[p.id] == tipo else 0
        return extra + _pontos(p, cores, restantes)

    # Mais pontos primeiro; empate pelo id, para a mesma entrada dar sempre o mesmo resultado.
    ordenadas = sorted(da_categoria, key=lambda p: (-pontos(p), str(p.id)))
    return Funil(etiqueta, categoria, cores, tuple(p.id for p in ordenadas[:MAX_CANDIDATAS]))


def estreitar(
    etiquetas: Sequence[str],
    pecas: Sequence[PecaCandidata],
    evitadas: Collection[uuid.UUID] = (),
) -> list[Funil]:
    """Um `Funil` por etiqueta, na ordem das etiquetas."""
    return [funil_da_etiqueta(etiqueta, pecas, evitadas) for etiqueta in etiquetas]
