"""Desempenho básico do motor com um armário grande (~100 peças)."""

import time
from itertools import cycle

from app.services.sugestoes.servico import sugerir
from app.services.sugestoes.tipos import Filtros, PreferenciasMotor, Restricoes
from tests.fabrica import peca

CORES = ["Branco", "Preto", "Cinza", "Bege", "Azul", "Vermelho", "Verde", "Rosa", "Amarelo", "Marrom"]
ESTILOS = ["Casual", "Elegante", "Streetwear"]


def _armario_grande():
    cores, estilos = cycle(CORES), cycle(ESTILOS)
    quantidades = {
        "Camisetas": 20, "Camisas": 10, "Calças": 15, "Saias": 5, "Vestidos": 10,
        "Sapatos": 15, "Casacos": 10, "Acessórios": 15,
    }
    return [
        peca(categoria, next(cores), estilo=next(estilos))
        for categoria, quantidade in quantidades.items()
        for _ in range(quantidade)
    ]


def test_armario_de_100_pecas_responde_em_ate_2_segundos():
    pecas = _armario_grande()
    assert len(pecas) == 100
    # Criatividade 5 e sobreposição preferida: o pior caso (casacos entram, quase tudo combina).
    prefs = PreferenciasMotor(criatividade=5, sobreposicoes=frozenset({"Jaqueta"}))

    inicio = time.perf_counter()
    resultado = sugerir(pecas, Filtros(), prefs, Restricoes(), {}, pagina=5)
    duracao = time.perf_counter() - inicio

    assert len(resultado.looks) == 3
    assert duracao < 2.0, f"levou {duracao:.2f}s"
