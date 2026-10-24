"""Funil de candidatas da ligação automática (E8.F5.1): funções puras, sem banco."""

import random
import uuid

import pytest

from app.services.inspiracao.candidatos import (
    MAX_CANDIDATAS,
    MOTIVO_NAO_ENTENDIDA,
    MOTIVO_SEM_PECA_DA_CATEGORIA,
    PecaCandidata,
    estreitar,
    funil_da_etiqueta,
)
from app.services.inspiracao.vocabulario import normalizar

_contador = 0


def peca(categoria, cor=None, subcategoria=None, cores_extras=()) -> PecaCandidata:
    """Peça com id crescente e estável (a ordem de desempate é previsível)."""
    global _contador
    _contador += 1
    return PecaCandidata(
        id=uuid.UUID(int=_contador),
        categoria=categoria,
        subcategoria=subcategoria,
        cor=cor,
        cores_extras=cores_extras,
    )


def ids(*pecas: PecaCandidata) -> tuple[uuid.UUID, ...]:
    return tuple(p.id for p in pecas)


# --- critérios de aceite


def test_calca_jeans_azul_traz_as_calcas_com_a_azul_de_jeans_primeiro():
    preta = peca("Calças", "Preto")
    azul_jeans = peca("Calças", "Azul", "jeans")
    camiseta_azul = peca("Camisetas", "Azul")

    funil = funil_da_etiqueta("calça jeans azul", [preta, camiseta_azul, azul_jeans])

    assert funil.categoria == "Calças"
    assert funil.cores == ("Azul",)
    assert funil.candidatas == ids(azul_jeans, preta)  # a camiseta não entra
    assert funil.motivo_lacuna is None


def test_sem_peca_da_categoria_e_lacuna_explicita():
    funil = funil_da_etiqueta("tênis branco", [peca("Calças", "Branco"), peca("Camisetas", "Branco")])

    assert funil.categoria == "Sapatos"
    assert funil.candidatas == ()
    assert funil.motivo_lacuna == MOTIVO_SEM_PECA_DA_CATEGORIA


def test_etiqueta_sem_palavra_reconhecida_e_lacuna():
    funil = funil_da_etiqueta("coisa estranha", [peca("Calças", "Preto")])

    assert funil.categoria is None
    assert funil.candidatas == ()
    assert funil.motivo_lacuna == MOTIVO_NAO_ENTENDIDA


def test_peca_evitada_nunca_aparece_nas_candidatas():
    boa = peca("Calças", "Azul")
    evitada = peca("Calças", "Azul", "jeans")  # combinaria mais, mas é evitada

    funil = funil_da_etiqueta("calça jeans azul", [evitada, boa], evitadas={evitada.id})

    assert funil.candidatas == ids(boa)


def test_se_so_ha_evitadas_da_categoria_e_lacuna():
    evitada = peca("Sapatos", "Preto")

    funil = funil_da_etiqueta("bota preta", [evitada], evitadas=[evitada.id])

    assert funil.candidatas == ()
    assert funil.motivo_lacuna == MOTIVO_SEM_PECA_DA_CATEGORIA


def test_no_maximo_4_candidatas_sempre_na_mesma_ordem():
    calcas = [peca("Calças", "Preto") for _ in range(10)]
    azul = peca("Calças", "Azul")
    todas = [*calcas, azul]

    funil = funil_da_etiqueta("calça azul", todas)
    assert len(funil.candidatas) == MAX_CANDIDATAS == 4
    assert funil.candidatas[0] == azul.id  # a de cor certa vai na frente

    # A ordem de entrada não muda o resultado.
    for semente in range(5):
        embaralhadas = todas[:]
        random.Random(semente).shuffle(embaralhadas)
        assert funil_da_etiqueta("calça azul", embaralhadas) == funil


# --- categoria: singular, plural, acento, caixa


@pytest.mark.parametrize(
    ("etiqueta", "categoria"),
    [
        ("camiseta branca", "Camisetas"),
        ("Camisetas BRANCAS", "Camisetas"),
        ("camisa de linho", "Camisas"),
        ("blusa de seda", "Blusas"),
        ("regata preta", "Regatas"),
        ("suéter rosa claro", "Suéteres"),
        ("moletom cinza", "Suéteres"),
        ("calça jeans", "Calças"),
        ("Calças azuis", "Calças"),
        ("shorts jeans", "Shorts"),
        ("bermuda", "Shorts"),
        ("calções jeans azul escuro", "Shorts"),
        ("saia plissada", "Saias"),
        ("vestido longo", "Vestidos"),
        ("macacão preto", "Macacões"),
        ("macacões", "Macacões"),
        ("jaqueta de couro", "Casacos"),
        ("cardigã bege", "Casacos"),
        ("blazers", "Casacos"),
        ("TÊNIS branco", "Sapatos"),
        ("tênis de salto", "Sapatos"),
        ("sandália dourada", "Sapatos"),
        ("botas pretas", "Sapatos"),
        ("bolsa pequena", "Acessórios"),
        ("óculos de sol", "Acessórios"),
        ("joias douradas", "Acessórios"),
        ("meia alta branca", "Acessórios"),
    ],
)
def test_categoria_da_etiqueta(etiqueta, categoria):
    assert funil_da_etiqueta(etiqueta, []).categoria == categoria


def test_vale_a_primeira_palavra_de_categoria():
    # "jaqueta jeans" é casaco, não calça; "bolsa de couro" é acessório.
    assert funil_da_etiqueta("jaqueta jeans", []).categoria == "Casacos"
    assert funil_da_etiqueta("bota de salto", []).categoria == "Sapatos"


# --- cores


@pytest.mark.parametrize(
    ("etiqueta", "cores"),
    [
        ("camiseta preta", ("Preto",)),
        ("camisetas brancas", ("Branco",)),
        ("calça azul marinho", ("Azul-marinho",)),
        ("calça azul-marinho", ("Azul-marinho",)),
        ("jaqueta azul claro", ("Azul-claro",)),
        ("calça azul", ("Azul",)),
        ("vestido lilás", ("Roxo",)),
        ("bolsa marrom e bege", ("Marrom", "Bege")),
        ("camiseta preta preta", ("Preto",)),
        ("camiseta", ()),
    ],
)
def test_cores_da_etiqueta(etiqueta, cores):
    assert funil_da_etiqueta(etiqueta, []).cores == cores


def test_azul_marinho_nao_e_o_mesmo_que_azul():
    marinho = peca("Calças", "Azul-marinho")
    azul = peca("Calças", "Azul")

    assert funil_da_etiqueta("calça azul marinho", [azul, marinho]).candidatas[0] == marinho.id
    assert funil_da_etiqueta("calça azul", [marinho, azul]).candidatas[0] == azul.id


def test_cor_secundaria_de_peca_multicolorida_tambem_conta():
    multicolor = peca("Camisetas", "Rosa", cores_extras=("Branco",))
    preta = peca("Camisetas", "Preto")

    assert funil_da_etiqueta("camiseta branca", [preta, multicolor]).candidatas == ids(multicolor, preta)


# --- pontuação: cor, subcategoria e o que fica de fora


def test_peca_de_cor_diferente_continua_candidata_mas_por_ultimo():
    vermelha = peca("Saias", "Vermelho")
    azul = peca("Saias", "Azul")

    assert funil_da_etiqueta("saia azul", [vermelha, azul]).candidatas == ids(azul, vermelha)


def test_palavra_da_etiqueta_na_subcategoria_desempata():
    lisa = peca("Camisas", "Branco", "social")
    linho = peca("Camisas", "Branco", "linho")

    assert funil_da_etiqueta("camisa branca de linho", [lisa, linho]).candidatas == ids(linho, lisa)


def test_cor_vale_mais_que_uma_palavra_da_subcategoria():
    cor_certa = peca("Calças", "Azul", "reta")
    so_subcategoria = peca("Calças", "Preto", "jeans")

    funil = funil_da_etiqueta("calça jeans azul", [so_subcategoria, cor_certa])
    # cor certa = 2 pontos; só "jeans" = 1 ponto
    assert funil.candidatas == ids(cor_certa, so_subcategoria)


def test_palavras_vazias_e_curtas_nao_pontuam():
    a = peca("Calças", "Preto", "de")
    b = peca("Calças", "Preto", "reta")

    # "de" e "da" sobram na etiqueta mas não são palavras úteis: empate por id.
    assert funil_da_etiqueta("calça de preta da", [b, a]).candidatas == ids(a, b)


def test_subcategoria_ausente_ou_com_acento_nao_quebra():
    sem = peca("Camisas", "Branco", None)
    com_acento = peca("Camisas", "Branco", "Algodão egípcio")

    funil = funil_da_etiqueta("camisa branca algodao", [sem, com_acento])
    assert funil.candidatas == ids(com_acento, sem)


# --- vários e entrada sem peças


def test_estreitar_devolve_um_funil_por_etiqueta_na_ordem_dada():
    calca = peca("Calças", "Azul", "jeans")
    tenis = peca("Sapatos", "Branco")

    funis = estreitar(["tênis branco", "coisa estranha", "calça jeans azul", "bolsa preta"], [calca, tenis])

    assert [f.etiqueta for f in funis] == ["tênis branco", "coisa estranha", "calça jeans azul", "bolsa preta"]
    assert funis[0].candidatas == ids(tenis)
    assert funis[1].motivo_lacuna == MOTIVO_NAO_ENTENDIDA
    assert funis[2].candidatas == ids(calca)
    assert funis[3].motivo_lacuna == MOTIVO_SEM_PECA_DA_CATEGORIA


def test_sem_etiquetas_ou_sem_pecas():
    assert estreitar([], [peca("Calças")]) == []
    assert estreitar(["calça azul"], [])[0].motivo_lacuna == MOTIVO_SEM_PECA_DA_CATEGORIA


def test_etiqueta_vazia_ou_so_pontuacao_nao_e_entendida():
    for etiqueta in ("", "   ", "!!!"):
        assert funil_da_etiqueta(etiqueta, []).motivo_lacuna == MOTIVO_NAO_ENTENDIDA


def test_normalizar():
    assert normalizar("  Calça  Jeans-AZUL! ") == "calca jeans azul"
    assert normalizar("TÊNIS") == "tenis"


# --- tipo dentro de categorias largas (sapatos, acessórios)


def test_bota_so_concorre_com_bota_nao_com_tenis_nem_salto():
    bota = peca("Sapatos", "Marrom", "Botas de cano alto")
    tenis = peca("Sapatos", "Vermelho", "Tênis")
    salto = peca("Sapatos", "Marrom", "Salto")

    funil = funil_da_etiqueta("botas pretas", [tenis, salto, bota])

    assert funil.candidatas == ids(bota)  # a cor diferente não elimina a bota


def test_peca_de_tipo_desconhecido_so_entra_se_nao_ha_peca_do_tipo_exato():
    bota = peca("Sapatos", "Marrom", "Botas de cano alto")
    desconhecida = peca("Sapatos", "Rosa", "Adidas Gazelle")
    sem_subcategoria = peca("Sapatos", "Preto")

    com_bota = funil_da_etiqueta("bota preta", [desconhecida, sem_subcategoria, bota])
    assert com_bota.candidatas == ids(bota)

    sem_bota = funil_da_etiqueta("bota preta", [desconhecida, sem_subcategoria])
    assert set(sem_bota.candidatas) == set(ids(desconhecida, sem_subcategoria))


def test_sem_peca_do_tipo_e_lacuna_com_o_motivo_do_tipo():
    from app.services.inspiracao.candidatos import MOTIVO_SEM_PECA_DO_TIPO

    funil = funil_da_etiqueta("tênis branco", [peca("Sapatos", "Marrom", "Botas de cano alto")])

    assert funil.candidatas == ()
    assert funil.motivo_lacuna == MOTIVO_SEM_PECA_DO_TIPO


def test_meia_nao_e_bolsa_dentro_de_acessorios():
    bolsa = peca("Acessórios", "Marrom", "Bolsa de ombro")

    assert funil_da_etiqueta("meia preta", [bolsa]).candidatas == ()
    assert funil_da_etiqueta("bolsa pequena preta", [bolsa]).candidatas == ids(bolsa)
    assert funil_da_etiqueta("colar prata", [bolsa]).candidatas == ()


def test_sapato_generico_nao_restringe_o_tipo():
    bota = peca("Sapatos", "Marrom", "Botas de cano alto")
    tenis = peca("Sapatos", "Vermelho", "Tênis")

    assert set(funil_da_etiqueta("sapatos pretos", [bota, tenis]).candidatas) == set(ids(bota, tenis))


def test_tipo_exato_vale_mais_que_a_cor_na_ordem():
    bota_marrom = peca("Sapatos", "Marrom", "Bota")
    sem_tipo_preta = peca("Sapatos", "Preto")

    assert funil_da_etiqueta("bota preta", [sem_tipo_preta, bota_marrom]).candidatas == ids(bota_marrom)


def test_tipo_vem_da_etiqueta_inteira_sapatos_de_salto():
    salto = peca("Sapatos", "Marrom", "Salto")
    tenis = peca("Sapatos", "Branco", "Tênis")

    assert funil_da_etiqueta("sapatos de salto preto", [tenis, salto]).candidatas == ids(salto)
