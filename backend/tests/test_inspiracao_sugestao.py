"""Sugestão de look a partir de uma referência (E8.F5.2): orquestração pura, com a
comparação visual, as fotos e o relógio simulados (nada de Ollama nem de disco)."""

import uuid

from app.services.inspiracao.candidatos import PecaCandidata
from app.services.inspiracao.sugestao import (
    MAX_ETIQUETAS_ANALISADAS,
    SITUACAO_ENCONTRADA,
    SITUACAO_NAO_ANALISADA,
    SITUACAO_NAO_ENTENDIDA,
    SITUACAO_SEM_EQUIVALENTE,
    TIPO_LOOK_NOVO,
    TIPO_LOOK_SALVO,
    TIPO_SEM_PECAS,
    sugerir_look,
)

_contador = 0
REFERENCIA = b"foto-da-referencia"


def peca(categoria, cor=None, subcategoria=None) -> PecaCandidata:
    global _contador
    _contador += 1
    return PecaCandidata(id=uuid.UUID(int=_contador), categoria=categoria, cor=cor, subcategoria=subcategoria)


def foto(peca_id) -> bytes:
    return f"foto-{peca_id}".encode()


class Cena:
    """Monta as entradas e guarda o que a "IA" recebeu."""

    def __init__(self, pecas, escolhas=None, looks=None, evitadas=(), sem_foto=(), tempo_por_chamada=0.0):
        self.pecas = pecas
        self.escolhas = escolhas or {}  # etiqueta -> peça que a IA aponta
        self.looks = looks or {}
        self.evitadas = set(evitadas)
        self.sem_foto = set(sem_foto)
        self.chamadas: list[tuple[str, list[bytes]]] = []
        self._agora = 0.0
        self._passo = tempo_por_chamada

    def _ler(self, peca_id):
        if peca_id in self.sem_foto:
            raise FileNotFoundError(peca_id)
        return foto(peca_id)

    def _escolher(self, referencia, etiqueta, candidatas):
        assert referencia == REFERENCIA
        self.chamadas.append((etiqueta, candidatas))
        self._agora += self._passo
        alvo = self.escolhas.get(etiqueta)
        if isinstance(alvo, Exception):
            raise alvo
        if isinstance(alvo, int) and not isinstance(alvo, bool) and alvo not in self.pecas_ids():
            return alvo  # índice cru (para testar índice inválido)
        if alvo is None:
            return None
        pelo_id = foto(alvo)
        return candidatas.index(pelo_id) if pelo_id in candidatas else None

    def pecas_ids(self):
        return {p.id for p in self.pecas}

    def rodar(self, etiquetas, tempo_max_s=120.0):
        return sugerir_look(
            etiquetas=etiquetas,
            pecas=self.pecas,
            evitadas=self.evitadas,
            looks_salvos=self.looks,
            imagem_referencia=REFERENCIA,
            ler_imagem=self._ler,
            escolher=self._escolher,
            tempo_max_s=tempo_max_s,
            relogio=lambda: self._agora,
        )


def armario():
    return peca("Calças", "Azul", "jeans"), peca("Sapatos", "Branco"), peca("Camisetas", "Branco")


# --- tipos de resultado


def test_look_novo_com_as_pecas_achadas_na_ordem_das_etiquetas():
    calca, tenis, camiseta = armario()
    cena = Cena([calca, tenis, camiseta], {"calça jeans azul": calca.id, "tênis branco": tenis.id, "camiseta branca": camiseta.id})

    r = cena.rodar(["camiseta branca", "calça jeans azul", "tênis branco"])

    assert r.tipo == TIPO_LOOK_NOVO
    assert r.look_id is None
    assert r.pecas_ids == (camiseta.id, calca.id, tenis.id)
    assert [i.situacao for i in r.itens] == [SITUACAO_ENCONTRADA] * 3
    assert r.lacunas == ()


def test_look_salvo_que_contem_todas_as_pecas_achadas():
    calca, tenis, camiseta = armario()
    cena = Cena(
        [calca, tenis, camiseta],
        {"calça azul": calca.id, "tênis branco": tenis.id},
        looks={
            uuid.UUID(int=900): [calca.id, tenis.id, camiseta.id],
            uuid.UUID(int=901): [calca.id],  # não tem todas
        },
    )

    r = cena.rodar(["calça azul", "tênis branco"])

    assert r.tipo == TIPO_LOOK_SALVO
    assert r.look_id == uuid.UUID(int=900)
    assert set(r.pecas_ids) == {calca.id, tenis.id}


def test_entre_looks_que_servem_vence_o_de_menos_pecas_a_mais():
    calca, tenis, camiseta = armario()
    cena = Cena(
        [calca, tenis, camiseta],
        {"calça azul": calca.id, "tênis branco": tenis.id},
        looks={
            uuid.UUID(int=910): [calca.id, tenis.id, camiseta.id],
            uuid.UUID(int=911): [calca.id, tenis.id],
            uuid.UUID(int=912): [camiseta.id, calca.id, tenis.id],
        },
    )

    assert cena.rodar(["calça azul", "tênis branco"]).look_id == uuid.UUID(int=911)


def test_look_salvo_empatado_desempata_pelo_id():
    calca, tenis, _ = armario()
    looks = {uuid.UUID(int=921): [calca.id, tenis.id], uuid.UUID(int=920): [tenis.id, calca.id]}
    cena = Cena([calca, tenis], {"calça azul": calca.id, "tênis branco": tenis.id}, looks=looks)

    assert cena.rodar(["calça azul", "tênis branco"]).look_id == uuid.UUID(int=920)


def test_com_uma_peca_so_o_resultado_e_look_novo_mesmo_que_um_look_salvo_a_tenha():
    calca, tenis, _ = armario()
    cena = Cena([calca, tenis], {"calça azul": calca.id}, looks={uuid.UUID(int=930): [calca.id, tenis.id]})

    r = cena.rodar(["calça azul"])

    assert r.tipo == TIPO_LOOK_NOVO
    assert r.pecas_ids == (calca.id,)


def test_sem_nenhuma_peca_escolhida_e_sem_pecas_com_todas_as_lacunas():
    calca, tenis, _ = armario()
    cena = Cena([calca, tenis], {})  # a IA responde "nenhuma" para tudo

    r = cena.rodar(["calça azul", "tênis branco"])

    assert r.tipo == TIPO_SEM_PECAS
    assert r.pecas_ids == ()
    assert r.lacunas == ("calça azul", "tênis branco")
    assert all(i.situacao == SITUACAO_SEM_EQUIVALENTE for i in r.itens)


# --- lacunas e o que nunca vai à IA


def test_etiqueta_sem_peca_da_categoria_ou_nao_entendida_vira_lacuna_sem_chamar_a_ia():
    calca, _, _ = armario()
    cena = Cena([calca], {"calça azul": calca.id})

    r = cena.rodar(["calça azul", "bolsa preta", "coisa estranha"])

    assert r.tipo == TIPO_LOOK_NOVO
    assert [(i.etiqueta, i.situacao) for i in r.itens] == [
        ("calça azul", SITUACAO_ENCONTRADA),
        ("bolsa preta", SITUACAO_SEM_EQUIVALENTE),
        ("coisa estranha", SITUACAO_NAO_ENTENDIDA),
    ]
    assert r.lacunas == ("bolsa preta", "coisa estranha")
    assert [etiqueta for etiqueta, _ in cena.chamadas] == ["calça azul"]  # só a que tinha candidata


def test_peca_evitada_nunca_chega_a_ia_nem_ao_resultado():
    boa = peca("Calças", "Azul")
    evitada = peca("Calças", "Azul", "jeans")  # combinaria melhor, mas é evitada
    cena = Cena([boa, evitada], {"calça jeans azul": evitada.id}, evitadas=[evitada.id])

    r = cena.rodar(["calça jeans azul"])

    assert cena.chamadas == [("calça jeans azul", [foto(boa.id)])]
    assert evitada.id not in r.pecas_ids
    assert r.tipo == TIPO_SEM_PECAS  # a IA apontou a evitada, que não estava entre as opções


def test_so_evitadas_na_categoria_nao_chama_a_ia():
    evitada = peca("Sapatos", "Preto")
    cena = Cena([evitada], {"bota preta": evitada.id}, evitadas=[evitada.id])

    r = cena.rodar(["bota preta"])

    assert cena.chamadas == []
    assert r.lacunas == ("bota preta",)


def test_a_ia_recebe_a_foto_da_referencia_a_etiqueta_e_as_candidatas_do_funil():
    azul = peca("Calças", "Azul", "jeans")
    preta = peca("Calças", "Preto")
    cena = Cena([preta, azul, peca("Camisetas", "Azul")])

    cena.rodar(["calça jeans azul"])

    assert cena.chamadas == [("calça jeans azul", [foto(azul.id), foto(preta.id)])]  # a azul primeiro


def test_uma_peca_nao_vale_por_duas_etiquetas():
    so_uma_bolsa = peca("Acessórios", "Marrom")
    cena = Cena([so_uma_bolsa], {"bolsa marrom": so_uma_bolsa.id, "cinto marrom": so_uma_bolsa.id})

    r = cena.rodar(["bolsa marrom", "cinto marrom"])

    assert r.pecas_ids == (so_uma_bolsa.id,)
    assert [i.situacao for i in r.itens] == [SITUACAO_ENCONTRADA, SITUACAO_SEM_EQUIVALENTE]
    assert len(cena.chamadas) == 1  # o cinto não tinha mais candidata


# --- falhas

def test_falha_da_ia_numa_etiqueta_nao_derruba_as_outras():
    calca, tenis, _ = armario()
    cena = Cena([calca, tenis], {"calça azul": RuntimeError("ollama caiu"), "tênis branco": tenis.id})

    r = cena.rodar(["calça azul", "tênis branco"])

    assert [i.situacao for i in r.itens] == [SITUACAO_SEM_EQUIVALENTE, SITUACAO_ENCONTRADA]
    assert r.pecas_ids == (tenis.id,)


def test_indice_invalido_da_ia_vira_sem_equivalente():
    calca, _, _ = armario()
    cena = Cena([calca], {"calça azul": 7})  # só há uma candidata

    r = cena.rodar(["calça azul"])

    assert r.itens[0].situacao == SITUACAO_SEM_EQUIVALENTE


def test_foto_da_candidata_sumiu_do_disco_a_candidata_e_ignorada():
    sumida = peca("Calças", "Azul", "jeans")
    outra = peca("Calças", "Preto")
    cena = Cena([sumida, outra], {"calça jeans azul": outra.id}, sem_foto=[sumida.id])

    r = cena.rodar(["calça jeans azul"])

    assert cena.chamadas == [("calça jeans azul", [foto(outra.id)])]
    assert r.pecas_ids == (outra.id,)


def test_todas_as_fotos_sumidas_vira_sem_equivalente_sem_chamar_a_ia():
    sumida = peca("Calças", "Azul")
    cena = Cena([sumida], {"calça azul": sumida.id}, sem_foto=[sumida.id])

    r = cena.rodar(["calça azul"])

    assert cena.chamadas == []
    assert r.itens[0].situacao == SITUACAO_SEM_EQUIVALENTE


# --- tempo e limite


def test_orcamento_de_tempo_esgotado_deixa_o_resto_como_nao_analisado():
    calca, tenis, camiseta = armario()
    cena = Cena(
        [calca, tenis, camiseta],
        {"calça azul": calca.id, "tênis branco": tenis.id, "camiseta branca": camiseta.id},
        tempo_por_chamada=100.0,
    )

    r = cena.rodar(["calça azul", "tênis branco", "camiseta branca"], tempo_max_s=150.0)

    assert [i.situacao for i in r.itens] == [SITUACAO_ENCONTRADA, SITUACAO_ENCONTRADA, SITUACAO_NAO_ANALISADA]
    assert len(cena.chamadas) == 2
    assert r.tipo == TIPO_LOOK_NOVO
    assert r.lacunas == ()  # "não analisada" não é lacuna: só não deu tempo


def test_tempo_zerado_nao_analisa_nenhuma_etiqueta_com_candidata_mas_ainda_aponta_lacunas():
    calca, _, _ = armario()
    cena = Cena([calca], {"calça azul": calca.id})

    r = cena.rodar(["calça azul", "bolsa preta"], tempo_max_s=0.0)

    assert [(i.etiqueta, i.situacao) for i in r.itens] == [
        ("calça azul", SITUACAO_NAO_ANALISADA),
        ("bolsa preta", SITUACAO_SEM_EQUIVALENTE),
    ]
    assert cena.chamadas == []
    assert r.tipo == TIPO_SEM_PECAS


def test_so_as_primeiras_6_etiquetas_sao_analisadas():
    pecas = [peca("Camisetas", f"Cor{i}") for i in range(1)]
    cena = Cena(pecas, {})
    etiquetas = [f"camiseta {i}" for i in range(8)]

    r = cena.rodar(etiquetas)

    assert MAX_ETIQUETAS_ANALISADAS == 6
    assert len(r.itens) == 8
    assert [i.situacao for i in r.itens[6:]] == [SITUACAO_NAO_ANALISADA] * 2
    assert len(cena.chamadas) <= 6


def test_sem_etiquetas_ou_sem_pecas():
    assert Cena([], {}).rodar([]).tipo == TIPO_SEM_PECAS
    r = Cena([], {}).rodar(["calça azul"])
    assert r.tipo == TIPO_SEM_PECAS
    assert r.lacunas == ("calça azul",)


def test_mesma_entrada_mesmo_resultado():
    calca, tenis, camiseta = armario()
    escolhas = {"calça azul": calca.id, "tênis branco": tenis.id}
    looks = {uuid.UUID(int=940): [calca.id, tenis.id]}

    primeiro = Cena([calca, tenis, camiseta], escolhas, looks).rodar(["calça azul", "tênis branco"])
    segundo = Cena([camiseta, tenis, calca], escolhas, looks).rodar(["calça azul", "tênis branco"])

    assert primeiro == segundo
