import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'upload_controller.dart';

/// Cadastro de peça por foto — cobre a PBI E1.F1.1 (captura/seleção + preview)
/// e a E1.F1.3 (envio pro backend + exibição do resultado).
/// Revisão/edição dos metadados sugeridos e o `POST /pecas` final ficam para
/// a Feature 2 (fora do escopo desta tela por ora).
/// Ver docs/PBIs/E1-F1-adicionar-foto/.
class UploadView extends ConsumerWidget {
  const UploadView({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, ImageSource source) async {
    try {
      final controller = ref.read(uploadPhotoProvider.notifier);
      if (source == ImageSource.camera) {
        await controller.pickFromCamera();
      } else {
        await controller.pickFromGallery();
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível acessar a câmera/galeria. Verifique as permissões do app.'),
        ),
      );
    }
  }

  void _showSourcePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(context, ref, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(context, ref, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final XFile? foto = ref.watch(uploadPhotoProvider);
    final EnvioState envioState = ref.watch(uploadSubmissionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Peça')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: foto == null
            ? _EscolhaDeFoto(
                onTirarFoto: () => _pick(context, ref, ImageSource.camera),
                onEscolherDaGaleria: () => _pick(context, ref, ImageSource.gallery),
              )
            : _conteudoComFoto(context, ref, foto, envioState),
      ),
    );
  }

  Widget _conteudoComFoto(
    BuildContext context,
    WidgetRef ref,
    XFile foto,
    EnvioState envioState,
  ) {
    void onTrocarFoto() => _showSourcePicker(context, ref);

    return switch (envioState) {
      EnvioIdle() => _PreviewDeFoto(
          foto: foto,
          onTrocarFoto: onTrocarFoto,
          onConfirmar: () => ref.read(uploadSubmissionProvider.notifier).enviar(),
        ),
      Enviando() => _Processando(foto: foto),
      EnvioSucesso(:final imagemUrl, :final semRemocaoDeFundo) => _ResultadoProcessado(
          imagemUrl: imagemUrl,
          semRemocaoDeFundo: semRemocaoDeFundo,
          onNovaFoto: onTrocarFoto,
        ),
      EnvioErro(:final mensagem) => _ErroEnvio(
          mensagem: mensagem,
          onTentarNovamente: () => ref.read(uploadSubmissionProvider.notifier).enviar(),
          onContinuarSemProcessamento: () =>
              ref.read(uploadSubmissionProvider.notifier).continuarSemProcessamento(),
          onTrocarFoto: onTrocarFoto,
        ),
    };
  }
}

class _EscolhaDeFoto extends StatelessWidget {
  const _EscolhaDeFoto({required this.onTirarFoto, required this.onEscolherDaGaleria});

  final VoidCallback onTirarFoto;
  final VoidCallback onEscolherDaGaleria;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.checkroom, size: 64),
          const SizedBox(height: 16),
          const Text('Adicione uma foto da peça'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onTirarFoto,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Tirar foto'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onEscolherDaGaleria,
            icon: const Icon(Icons.photo_library),
            label: const Text('Escolher da galeria'),
          ),
        ],
      ),
    );
  }
}

class _FotoPreviewImage extends StatelessWidget {
  const _FotoPreviewImage({required this.foto, this.opacidade = 1});

  final XFile foto;
  final double opacidade;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacidade,
      // Image.memory (não Image.file/dart:io) — funciona também no
      // Flutter Web, hoje nossa única plataforma validada.
      child: FutureBuilder<Uint8List>(
        future: foto.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Image.memory(snapshot.data!, fit: BoxFit.contain);
        },
      ),
    );
  }
}

class _PreviewDeFoto extends StatelessWidget {
  const _PreviewDeFoto({
    required this.foto,
    required this.onTrocarFoto,
    required this.onConfirmar,
  });

  final XFile foto;
  final VoidCallback onTrocarFoto;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _FotoPreviewImage(foto: foto)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton(onPressed: onTrocarFoto, child: const Text('Trocar foto')),
            ElevatedButton(onPressed: onConfirmar, child: const Text('Confirmar')),
          ],
        ),
      ],
    );
  }
}

class _Processando extends StatelessWidget {
  const _Processando({required this.foto});

  final XFile foto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _FotoPreviewImage(foto: foto, opacidade: 0.4),
              const CircularProgressIndicator(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Processando foto...'),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ResultadoProcessado extends StatelessWidget {
  const _ResultadoProcessado({
    required this.imagemUrl,
    required this.onNovaFoto,
    this.semRemocaoDeFundo = false,
  });

  final String imagemUrl;
  final VoidCallback onNovaFoto;
  final bool semRemocaoDeFundo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Image.network(
            imagemUrl,
            fit: BoxFit.contain,
            // Sem isso, uma falha ao carregar a URL processada (ex: rede
            // caiu bem depois do upload responder) reporta um erro não
            // tratado em vez de degradar visualmente.
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image_outlined, size: 64),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          semRemocaoDeFundo
              ? 'Continuando sem remoção de fundo — você pode ajustar isso depois.'
              : 'Fundo removido! Revise os dados na próxima etapa.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: onNovaFoto, child: const Text('Adicionar outra foto')),
      ],
    );
  }
}

class _ErroEnvio extends StatelessWidget {
  const _ErroEnvio({
    required this.mensagem,
    required this.onTentarNovamente,
    required this.onContinuarSemProcessamento,
    required this.onTrocarFoto,
  });

  final String mensagem;
  final VoidCallback onTentarNovamente;
  final VoidCallback onContinuarSemProcessamento;
  final VoidCallback onTrocarFoto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(mensagem, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(onPressed: onTrocarFoto, child: const Text('Trocar foto')),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: onTentarNovamente, child: const Text('Tentar novamente')),
            ],
          ),
          const SizedBox(height: 12),
          // E1.F1.4: nunca deixar o cadastro travado esperando o
          // processamento funcionar — sempre existe uma saída.
          TextButton(
            onPressed: onContinuarSemProcessamento,
            child: const Text('Continuar sem remoção de fundo'),
          ),
        ],
      ),
    );
  }
}
