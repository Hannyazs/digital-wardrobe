"""Validação do `PATCH /looks/{id}` (schema puro, sem banco): `nome` (E5.F3.1)
e `peca_ids` (E3.F5.2)."""

import uuid

import pytest
from pydantic import ValidationError

from app.schemas.look import LookUpdate


def test_nome_valido_tem_espacos_removidos():
    dados = LookUpdate.model_validate({"nome": "  Trabalho segunda  "})
    assert dados.model_dump(exclude_unset=True) == {"nome": "Trabalho segunda"}


@pytest.mark.parametrize("nome", ["", "   ", None])
def test_nome_vazio_so_espacos_ou_nulo_e_recusado(nome):
    with pytest.raises(ValidationError):
        LookUpdate.model_validate({"nome": nome})


def test_sem_nome_nao_mexe_no_nome():
    # Atualização parcial: só o que veio no corpo é aplicado pelo router.
    dados = LookUpdate.model_validate({"favorito": True})
    assert dados.model_dump(exclude_unset=True) == {"favorito": True}


def test_nome_junto_dos_outros_campos():
    dados = LookUpdate.model_validate({"nome": "Festa", "ocasioes": [" Festa ", "Festa"]})
    assert dados.model_dump(exclude_unset=True) == {"nome": "Festa", "ocasioes": ["Festa"]}


# --- E3.F5.2: troca das peças ---


def test_peca_ids_validos_sao_aceitos():
    a, b = uuid.uuid4(), uuid.uuid4()
    dados = LookUpdate.model_validate({"peca_ids": [str(a), str(b)]})
    assert dados.model_dump(exclude_unset=True) == {"peca_ids": [a, b]}


@pytest.mark.parametrize("peca_ids", [[], None, ["nao-e-uuid"]])
def test_peca_ids_vazio_nulo_ou_invalido_e_recusado(peca_ids):
    with pytest.raises(ValidationError):
        LookUpdate.model_validate({"peca_ids": peca_ids})
