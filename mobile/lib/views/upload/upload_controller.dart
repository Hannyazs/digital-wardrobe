import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/state/envio_state.dart';
import '../../services/peca_service.dart';

/// Guarda a foto escolhida para o cadastro de uma peça, antes do envio ao
/// backend — isso é responsabilidade do E1.F1.3, não deste controller.
/// `null` significa que nenhuma foto foi escolhida ainda.
class UploadPhotoController extends Notifier<XFile?> {
  final ImagePicker _picker = ImagePicker();

  /// Foto como veio da câmera/galeria. O recorte é sempre refeito a partir
  /// dela — recortar o recorte só encolheria a imagem a cada tentativa.
  XFile? _original;

  @override
  XFile? build() => null;

  /// Original disponível para (re)recortar; cai na foto atual se ela veio
  /// sem passar pelo seletor.
  XFile? get original => _original ?? state;

  Future<void> pickFromCamera() => _pick(ImageSource.camera);

  Future<void> pickFromGallery() => _pick(ImageSource.gallery);

  Future<void> _pick(ImageSource source) async {
    // Erros de plataforma (ex: permissão negada) sobem para a UI tratar —
    // este controller só atualiza o estado no caminho feliz. Se o usuário
    // cancelar o seletor sem escolher nada, `pickImage` retorna null e o
    // estado atual permanece (não sobrescreve com null).
    final XFile? arquivo = await _picker.pickImage(source: source);
    if (arquivo != null) {
      _original = arquivo;
      state = arquivo;
      ref.read(uploadSubmissionProvider.notifier).reset();
    }
  }

  /// Substitui a foto pelo recorte escolhido; o original fica guardado.
  void usarRecorte(Uint8List bytes) {
    state = XFile.fromData(bytes, name: 'recorte.png', mimeType: 'image/png');
    ref.read(uploadSubmissionProvider.notifier).reset();
  }

  void clear() {
    _original = null;
    state = null;
    ref.read(uploadSubmissionProvider.notifier).reset();
  }
}

final uploadPhotoProvider = NotifierProvider<UploadPhotoController, XFile?>(
  UploadPhotoController.new,
);

final pecaServiceProvider = Provider<PecaService>((ref) => PecaService());

/// Controller do envio da foto pro backend (E1.F1.3) — separado do
/// [UploadPhotoController] porque tem um ciclo de vida diferente: trocar a
/// foto reseta o envio, mas um erro de envio não deve descartar a foto
/// escolhida (o usuário precisa poder tentar de novo sem escolhê-la de novo).
/// O estado ([EnvioState]) é compartilhado com [PecaFormController] (E1.F2.1)
/// — ver core/state/envio_state.dart.
class UploadSubmissionController extends Notifier<EnvioState> {
  @override
  EnvioState build() => const EnvioIdle();

  Future<void> enviar() async {
    final foto = ref.read(uploadPhotoProvider);
    if (foto == null) return;

    state = const Enviando();
    try {
      final resultado = await ref.read(pecaServiceProvider).processarImagem(foto);
      state = EnvioSucesso(
        AppConstants.resolveMediaUrl(resultado['imagem_url'] as String),
      );
    } on DioException catch (e) {
      state = EnvioErro(_mensagemDeErro(e));
    } catch (_) {
      state = const EnvioErro('Não foi possível processar a foto. Tente novamente.');
    }
  }

  /// Fallback do E1.F1.4: continua o cadastro com a foto original quando o
  /// processamento (rembg/Gemini) falhou de forma persistente. Reaproveita
  /// o mesmo estado `EnvioErro` se também falhar — não é um beco sem saída
  /// dentro do beco sem saída, o usuário pode tentar de novo qualquer um
  /// dos dois caminhos.
  Future<void> continuarSemProcessamento() async {
    final foto = ref.read(uploadPhotoProvider);
    if (foto == null) return;

    state = const Enviando();
    try {
      final resultado = await ref.read(pecaServiceProvider).uploadImagemOriginal(foto);
      state = EnvioSucesso(
        AppConstants.resolveMediaUrl(resultado['imagem_url'] as String),
        semRemocaoDeFundo: true,
      );
    } on DioException catch (e) {
      state = EnvioErro(_mensagemDeErro(e));
    } catch (_) {
      state = const EnvioErro('Não foi possível continuar. Tente novamente.');
    }
  }

  void reset() {
    state = const EnvioIdle();
  }

  String _mensagemDeErro(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'O processamento demorou demais. Verifique sua conexão e tente novamente.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      default:
        // Cobre também erros HTTP estruturados do backend (422/500 da
        // E1.F1.2) — diferenciar a reação por tipo de falha é escopo da
        // E1.F1.4, não desta PBI.
        return 'Não foi possível processar a foto. Tente novamente.';
    }
  }
}

final uploadSubmissionProvider = NotifierProvider<UploadSubmissionController, EnvioState>(
  UploadSubmissionController.new,
);
