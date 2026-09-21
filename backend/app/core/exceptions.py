"""Exceções de domínio para o processamento de imagem de peças.

Ficam aqui (não em `adapters/rembg_adapter.py`) para que o router possa
tratá-las sem depender de um tipo de exceção específico do provedor de
remoção de fundo — se o rembg for trocado no futuro, essas exceções
continuam válidas. Ver CLAUDE.md, seção "Camadas do backend".
"""


class ImagemInvalidaError(Exception):
    """A imagem recebida não é um formato que o PIL consegue decodificar."""


class ProcessamentoImagemError(Exception):
    """Falha ao processar uma imagem válida (ex: remoção de fundo)."""
