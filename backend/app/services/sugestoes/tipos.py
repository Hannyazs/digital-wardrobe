"""Estruturas de entrada e saída do motor de combinação."""

import uuid
from collections.abc import Mapping
from dataclasses import dataclass, field
from datetime import date

# Categorias por nome, iguais a `categoriasFixas` do app. Acessórios e
# categorias fora destas listas não entram nos looks.
PARTES_DE_CIMA = frozenset({"Camisetas", "Camisas"})
PARTES_DE_BAIXO = frozenset({"Calças", "Saias"})
VESTIDOS = frozenset({"Vestidos"})
SAPATOS = frozenset({"Sapatos"})
CASACOS = frozenset({"Casacos"})

ESTACAO_TODAS = "Todas as estações"
ESTACOES_COM_CASACO = frozenset({"Outono", "Inverno"})


@dataclass(frozen=True)
class PecaMotor:
    id: uuid.UUID
    categoria: str
    cor: str | None = None
    tonalidade: str | None = None
    estilo: str | None = None
    estacao: str | None = None
    ocasioes: tuple[str, ...] = ()


@dataclass(frozen=True)
class Filtros:
    ocasiao: str | None = None
    estilo: str | None = None
    estacao: str | None = None
    cor: str | None = None


@dataclass(frozen=True)
class PreferenciasMotor:
    estilos: frozenset[str] = frozenset()
    sobreposicoes: frozenset[str] = frozenset()
    # Pares de nomes de cor, sem ordem: frozenset({"Amarelo", "Roxo"}).
    pares_favoritos: frozenset[frozenset[str]] = frozenset()
    criatividade: int = 3


@dataclass(frozen=True)
class Restricoes:
    pecas_evitadas: frozenset[uuid.UUID] = frozenset()
    pares_evitados: frozenset[frozenset[uuid.UUID]] = frozenset()


@dataclass(frozen=True)
class ContextoRotatividade:
    """Modo rotatividade do critério 5 (Épico 6): data de referência e último
    uso de cada peça antes dela. Sem este contexto, o critério 5 é só o total
    de usos (Épico 5)."""

    data: date
    ultimos_usos: Mapping[uuid.UUID, date] = field(default_factory=dict)


@dataclass(frozen=True)
class Conflito:
    """Peça-base com valor diferente de um filtro ativo."""

    filtro: str  # "ocasiao" | "estilo" | "estacao"
    valor_filtro: str
    valor_peca: str


@dataclass(frozen=True)
class Candidato:
    pecas: tuple[PecaMotor, ...]
    ousadia: int  # sem contar pares favoritos
    pares_favoritos: frozenset[frozenset[str]]
    coringas: frozenset[uuid.UUID]
    sem_sapato: bool
    base_evitada: bool = False


@dataclass
class ResultadoMontagem:
    candidatos: list[Candidato] = field(default_factory=list)
    conflitos: list[Conflito] = field(default_factory=list)
    limite_atingido: bool = False
    motivo: str | None = None
