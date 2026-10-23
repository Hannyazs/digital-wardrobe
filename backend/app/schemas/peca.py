import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, model_validator


class PecaBase(BaseModel):
    categoria: str
    subcategoria: str | None = None
    cor_principal: str | None = None
    cores_secundarias: list[str] = []
    estacoes: list[str] = []
    tonalidade_cor: str | None = None
    estilos: list[str] = []
    modelagem: str | None = None
    ocasioes: list[str] = []

    @model_validator(mode="after")
    def _limpar_cores_secundarias(self):
        # Sem cor predominante não há secundárias; repetidas e a própria
        # predominante saem.
        vistas = {self.cor_principal} if self.cor_principal else set()
        limpas = []
        for cor in self.cores_secundarias if self.cor_principal else []:
            if cor and cor not in vistas:
                vistas.add(cor)
                limpas.append(cor)
        self.cores_secundarias = limpas
        return self


class PecaCreate(PecaBase):
    imagem_url: str


class PecaUpdate(PecaBase):
    """Payload de PUT /pecas/{id} (E1.F3.1) — mesmos campos de PecaBase,
    nunca imagem_url: a foto da peça é imutável após o cadastro."""


class PecaRead(PecaBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    usuario_id: uuid.UUID
    imagem_url: str
    criado_em: datetime


class ImagemProcessadaResponse(BaseModel):
    """Resposta do endpoint de pré-processamento: imagem já tratada (rembg)
    mais os metadados sugeridos pela IA, para o usuário revisar antes de
    confirmar o cadastro (POST /pecas)."""

    imagem_url: str
    sugestao: PecaBase


class ImagemOriginalResponse(BaseModel):
    """Resposta do fallback de upload sem processamento (E1.F1.4): usado
    quando /processar-imagem falhou e o usuário optou por continuar sem
    remoção de fundo."""

    imagem_url: str
