/// Estado de um envio assíncrono ao backend (upload de foto, criação de
/// peça) — compartilhado entre [UploadSubmissionController] (E1.F1.3/E1.F1.4)
/// e [PecaFormController] (E1.F2.1) para não duplicar o mesmo sealed class
/// em dois arquivos.
sealed class EnvioState {
  const EnvioState();
}

class EnvioIdle extends EnvioState {
  const EnvioIdle();
}

class Enviando extends EnvioState {
  const Enviando();
}

class EnvioSucesso extends EnvioState {
  const EnvioSucesso(this.imagemUrl, {this.semRemocaoDeFundo = false, this.sugestao});

  final String imagemUrl;
  // true quando veio do fallback do E1.F1.4 (upload sem rembg), não do
  // caminho normal de processamento.
  final bool semRemocaoDeFundo;
  // Metadados sugeridos pela IA (E7.F1) em `POST /pecas/processar-imagem`.
  // Map em vez de modelo novo para não duplicar o PecaBase por quatro campos.
  final Map<String, dynamic>? sugestao;
}

class EnvioErro extends EnvioState {
  const EnvioErro(this.mensagem);

  final String mensagem;
}
