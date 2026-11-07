"""Consulta paginada e filtrada de peças (E11.F1.1).

As regras de filtro espelham `filtrarPecas` do app (mobile/lib/views/wardrobe/
wardrobe_controller.dart): OU dentro de um critério, E entre critérios; peça
"Todas as estações" serve para qualquer estação; peça multicolorida entra por
`cor_principal` ou por `cores_secundarias`. Mantenha as duas em sincronia.
"""

from sqlalchemy import Select, any_, func, or_, select
from sqlalchemy.sql.elements import ColumnElement

from app.db.models import Peca

# Espelho de `categoriasFixas` (mobile/lib/core/constants/peca_opcoes.dart): a
# gaveta "Outras" é toda categoria fora desta lista (o banco guarda texto livre).
CATEGORIAS_FIXAS = (
    "Camisetas",
    "Camisas",
    "Blusas",
    "Regatas",
    "Suéteres",
    "Calças",
    "Shorts",
    "Saias",
    "Vestidos",
    "Macacões",
    "Casacos",
    "Sapatos",
    "Acessórios",
)

TODAS_AS_ESTACOES = "Todas as estações"

LIMITE_MAXIMO = 100


def condicoes_de_filtro(
    *,
    categorias: list[str],
    outras: bool,
    cores: list[str],
    estacoes: list[str],
    ocasioes: list[str],
) -> list[ColumnElement[bool]]:
    """Condições a juntar com E. Lista vazia em um critério = sem restrição."""
    condicoes: list[ColumnElement[bool]] = []

    if categorias or outras:
        partes: list[ColumnElement[bool]] = []
        if categorias:
            partes.append(Peca.categoria.in_(categorias))
        if outras:
            partes.append(Peca.categoria.not_in(CATEGORIAS_FIXAS))
        condicoes.append(or_(*partes))

    if cores:
        condicoes.append(or_(Peca.cor_principal.in_(cores), Peca.cores_secundarias.overlap(cores)))

    if estacoes:
        condicoes.append(
            or_(Peca.estacoes.overlap(estacoes), TODAS_AS_ESTACOES == any_(Peca.estacoes))
        )

    if ocasioes:
        condicoes.append(Peca.ocasioes.overlap(ocasioes))

    return condicoes


def consulta_de_pecas(usuario_id, condicoes: list[ColumnElement[bool]]) -> Select:
    return (
        select(Peca)
        .where(Peca.usuario_id == usuario_id, *condicoes)
        .order_by(Peca.criado_em.desc(), Peca.id)
    )


def contagem_de_pecas(usuario_id, condicoes: list[ColumnElement[bool]]) -> Select:
    return select(func.count()).select_from(Peca).where(Peca.usuario_id == usuario_id, *condicoes)
